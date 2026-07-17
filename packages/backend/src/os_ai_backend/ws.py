from __future__ import annotations

import asyncio
import logging
import os
import threading
import uuid
from typing import Any, Dict, Optional

import httpx
from fastapi import WebSocket

try:
    import orjson as json  # type: ignore
except Exception:  # pragma: no cover - fallback if orjson not available
    import json  # type: ignore

from os_ai_core.orchestrator import Orchestrator, CancelToken

from os_ai_llm.interfaces import LLMClient
from os_ai_core.adapters.llm.legacy_gateway import LegacyLLMGateway
from os_ai_core.adapters.tools.composite_tool_gateway import CompositeToolGateway
from os_ai_core.adapters.tools.computer_specs import build_computer_tool_descriptor
from os_ai_core.adapters.tools.local_computer_provider import LocalComputerToolProvider
from os_ai_core.application.services.prompt_builder import DesktopPromptContext, PromptBuilder
from os_ai_core.application.use_cases.run_agent import RunAgentCommand, RunAgentUseCase
from os_ai_core.tools.registry import ToolRegistry

from os_ai_llm.config import LLM_PROVIDER as _DEFAULT_PROVIDER
from .ws_approval import WebSocketApprovalAdapter
from .ws_event_sink import WebSocketEventSink
_PROVIDER_DISPLAY = {"anthropic": "Anthropic", "openai": "OpenAI", "azure_openai": "Azure OpenAI"}

# pyautogui не является thread-safe - только один agent.run одновременно.
_agent_run_lock = threading.Lock()
from .jobs import jobs, Job
from .metrics import metrics


LOGGER_NAME = "os_ai.backend"


class WebSocketRPCHandler:
    """Minimal JSON-RPC 2.0 handler over WebSocket.

    Supported methods (phase 1):
      - session.create
      - agent.run
      - agent.cancel (MVP: no-op acknowledgement)
    """

    def __init__(self) -> None:
        self._logger = logging.getLogger(LOGGER_NAME)
        self._approval_adapters: dict[str, WebSocketApprovalAdapter] = {}
        self._approval_lock = threading.Lock()

    async def handle(self, websocket: WebSocket) -> None:
        # Extract API keys from WebSocket query parameters (sent by frontend)
        query_params = websocket.query_params
        api_keys = {
            'anthropic': query_params.get('anthropic_api_key'),
            'openai': query_params.get('openai_api_key'),
            'azure_openai': query_params.get('azure_openai_api_key'),
        }
        provider_options = {
            "azure_openai": {
                "endpoint": query_params.get("azure_openai_endpoint"),
                "deployment": query_params.get("azure_openai_deployment"),
                "api_version": query_params.get("azure_openai_api_version"),
            }
        }
        # Legacy: single api_key param
        legacy_key = query_params.get('api_key')

        def get_api_key(provider: str | None) -> str | None:
            """Get the appropriate API key for the given provider."""
            p = provider or _DEFAULT_PROVIDER
            key = api_keys.get(p)
            if key:
                return key
            # Fallback to legacy single key
            return legacy_key

        def get_provider_options(provider: str | None) -> dict[str, dict[str, str | None]] | None:
            p = provider or _DEFAULT_PROVIDER
            opts = provider_options.get(p, {})
            return provider_options if any(v for v in opts.values()) else None

        def create_session_for_provider(provider: str | None):
            options = get_provider_options(provider)
            if options is None:
                return self._create_session(provider, api_key=get_api_key(provider))
            return self._create_session(provider, api_key=get_api_key(provider), provider_options=options)

        if any(v for v in api_keys.values() if v):
            self._logger.info("API keys provided via WebSocket query params")
        else:
            self._logger.info("No API keys in WebSocket params, will use environment variables")

        metrics.inc("ws_connections", 1)
        try:
            while True:
                raw = await websocket.receive_text()
                try:
                    req = json.loads(raw)
                except Exception:
                    await self._send_error(websocket, None, -32700, "Parse error")
                    continue

                if not isinstance(req, dict):
                    await self._send_error(websocket, None, -32600, "Invalid Request")
                    continue

                req_id = req.get("id")
                method = req.get("method")
                params = req.get("params") or {}

                if method == "session.create":
                    provider = params.get("provider")
                    provider_display = _PROVIDER_DISPLAY.get(provider or _DEFAULT_PROVIDER, (provider or _DEFAULT_PROVIDER).title())
                    try:
                        session_id, client, tools, tool_gateway = self._normalize_session(
                            create_session_for_provider(provider)
                        )
                        self._logger.info("session.create -> %s (provider=%s)", session_id, provider or "default")
                        await self._send_result(websocket, req_id, {
                            "sessionId": session_id,
                            "capabilities": {"ws": True, "jsonrpc": True}
                        })
                    except RuntimeError as e:
                        self._logger.warning(
                            "session.create failed (provider=%s): %s",
                            provider or _DEFAULT_PROVIDER, str(e),
                        )
                        await self._send_error(websocket, req_id, -32000,
                            f"API key required. Please configure your {provider_display} API key in Settings.")
                elif method == "agent.run":
                    task_text = params.get("task") or ""
                    if not task_text:
                        await self._send_error(websocket, req_id, -32602, "Missing 'task'")
                        continue
                    provider = params.get("provider")
                    provider_display = _PROVIDER_DISPLAY.get(provider or _DEFAULT_PROVIDER, (provider or _DEFAULT_PROVIDER).title())
                    max_iterations = int(params.get("maxIterations", 30))
                    initial_messages = params.get("context") or []
                    attachments = params.get("attachments") or []
                    previous_response_id = params.get("previous_response_id")

                    # Build session and run orchestration in background
                    try:
                        session_id, client, tools, tool_gateway = self._normalize_session(
                            create_session_for_provider(provider)
                        )
                    except RuntimeError as e:
                        self._logger.warning(
                            "agent.run failed (provider=%s): %s",
                            provider or _DEFAULT_PROVIDER, str(e),
                        )
                        await self._send_error(websocket, req_id, -32000,
                            f"API key required. Please configure your {provider_display} API key in Settings.")
                        continue

                    job_id = str(uuid.uuid4())
                    self._logger.info("agent.run job=%s session=%s provider=%s", job_id, session_id, provider or "default")
                    await self._send_result(websocket, req_id, {"jobId": job_id, "sessionId": session_id})

                    # Register cancel token before starting the job
                    cancel_token = CancelToken()
                    jobs.register(Job(id=job_id, cancel=cancel_token))

                    asyncio.create_task(self._run_job_and_notify(
                        websocket=websocket,
                        job_id=job_id,
                        client=client,
                        tools=tools,
                        tool_gateway=tool_gateway,
                        task_text=task_text,
                        max_iterations=max_iterations,
                        cancel=cancel_token,
                        initial_messages=initial_messages,
                        attachments=attachments,
                        provider=provider,
                        previous_response_id=previous_response_id,
                    ))
                    # job started asynchronously
                elif method == "agent.cancel":
                    # idempotent cancel: treat unknown job as already finished/cancelled
                    job_id = params.get("jobId")
                    if job_id:
                        try:
                            cancelled = jobs.cancel(str(job_id))
                            self._logger.info("agent.cancel job=%s found=%s", job_id, cancelled)
                            ok = True
                        except Exception:
                            self._logger.warning("agent.cancel job=%s exception", job_id)
                            ok = True
                    else:
                        self._logger.warning("agent.cancel missing jobId")
                        ok = False
                    await self._send_result(websocket, req_id, {"ok": ok, "jobId": job_id})
                elif method == "approval.respond":
                    job_id = str(params.get("jobId") or "")
                    approval_id = str(params.get("approvalId") or "")
                    approved = params.get("approved") is True
                    ok = False
                    if job_id and approval_id:
                        with self._approval_lock:
                            adapter = self._approval_adapters.get(job_id)
                        ok = adapter.respond(approval_id, approved) if adapter is not None else False
                    await self._send_result(
                        websocket,
                        req_id,
                        {"ok": ok, "jobId": job_id, "approvalId": approval_id},
                    )
                else:
                    await self._send_error(websocket, req_id, -32601, "Method not found")
        finally:
            metrics.inc("ws_connections", -1)

    async def _run_job_and_notify(
        self,
        websocket: WebSocket,
        job_id: str,
        client: LLMClient,
        tools: ToolRegistry,
        tool_gateway: CompositeToolGateway,
        task_text: str,
        max_iterations: int,
        cancel: CancelToken,
        initial_messages: list | None = None,
        attachments: list | None = None,
        provider: str | None = None,
        previous_response_id: str | None = None,
    ) -> None:
        _provider = provider or _DEFAULT_PROVIDER
        tool_descs = [build_computer_tool_descriptor(_provider)]
        system_prompt = PromptBuilder().build_desktop_operator_prompt(
            DesktopPromptContext(action_first=True)
        )

        loop = asyncio.get_running_loop()

        event_sink = WebSocketEventSink(websocket, loop, job_id, self._send_event)
        approval = WebSocketApprovalAdapter(websocket, loop, job_id, self._send_event)
        with self._approval_lock:
            self._approval_adapters[job_id] = approval

        def _blocking_run() -> Dict[str, Any]:
            # Convert initial context from wire into Message[] if provided
            base_msgs = []
            try:
                from os_ai_llm.types import Message, TextPart
                if initial_messages:
                    for m in initial_messages:
                        if isinstance(m, dict):
                            role = m.get("role")
                            text = m.get("text")
                            if role and isinstance(text, str):
                                base_msgs.append(Message(role=role, content=[TextPart(text=text)]))
            except Exception as e:
                self._logger.debug("Failed to parse initial_messages: %s", e)
            # Inject attachments as user messages (images) before the task
            try:
                if attachments:
                    from os_ai_llm.types import ImagePart
                    for a in attachments:
                        if isinstance(a, dict):
                            fid = a.get("fileId")
                            name = a.get("name")
                            # Fetch file bytes via local filestore (FastAPI app has store), then base64
                            # Import lazily to avoid circulars
                            from .files import store as _store
                            try:
                                meta = _store.get(str(fid))
                                data = meta.path.read_bytes()
                                import base64
                                b64 = base64.b64encode(data).decode("ascii")
                                base_msgs.append(Message(role="user", content=[ImagePart(media_type=a.get("mime") or "application/octet-stream", data_base64=b64)]))
                            except Exception as e:
                                self._logger.debug("Failed to load attachment %s: %s", fid, e)
            except Exception as e:
                self._logger.debug("Failed to process attachments: %s", e)

            # Build initial provider_context if previous_response_id provided (resume)
            init_ctx = None
            if previous_response_id:
                init_ctx = {"previous_response_id": previous_response_id}

            # Run application runner by default. Keep legacy facade as explicit rollback.
            try:
                if _application_runner_enabled():
                    run_result = RunAgentUseCase(
                        llm=LegacyLLMGateway(client),
                        tools=tool_gateway,
                        events=event_sink,
                        approval=approval,
                    ).execute(
                        RunAgentCommand(
                            job_id=job_id,
                            task=task_text,
                            tool_descriptors=tool_descs,
                            system_prompt=system_prompt,
                            max_iterations=max_iterations,
                            cancel_token=cancel,
                            initial_messages=base_msgs,
                            initial_provider_context=init_ctx,
                        )
                    )
                    messages = run_result.messages
                    input_tokens = run_result.input_tokens
                    output_tokens = run_result.output_tokens
                    provider_context = run_result.provider_context
                else:
                    orch = Orchestrator(client, tools, tool_gateway=tool_gateway, approval=approval, use_application_runner=False)
                    messages = orch.run(
                        task_text,
                        tool_descs,
                        system_prompt,
                        max_iterations=max_iterations,
                        cancel_token=cancel,
                        on_event=event_sink.emit_legacy,
                        initial_messages=base_msgs,
                        initial_provider_context=init_ctx,
                    )
                    input_tokens = int(getattr(orch, "total_input_tokens", 0) or 0)
                    output_tokens = int(getattr(orch, "total_output_tokens", 0) or 0)
                    provider_context = orch.last_provider_context
            except httpx.HTTPStatusError as e:
                # Check for authentication/authorization errors
                if e.response.status_code in (401, 403):
                    _pd = _PROVIDER_DISPLAY.get(_provider, _provider.title())
                    raise RuntimeError(
                        f"Invalid or expired API key. Please check your {_pd} API key in Settings and ensure it is valid."
                    ) from e
                raise  # Re-raise other HTTP errors

            final_texts: list[str] = []
            for m in messages:
                if getattr(m, "role", None) == "assistant":
                    for p in (getattr(m, "content", []) or []):
                        try:
                            if getattr(p, "type", None) == "text":
                                txt = str(getattr(p, "text", ""))
                                if txt:
                                    final_texts.append(txt)
                        except Exception as e:
                            self._logger.debug("Failed to extract text from message part: %s", e)
            return {
                "text": "\n".join(final_texts).strip(),
                "usage": {
                    "input_tokens": input_tokens,
                    "output_tokens": output_tokens,
                },
                "status": "ok",
                "provider_context": provider_context,
            }

        def _locked_blocking_run():
            with _agent_run_lock:
                return _blocking_run()

        try:
            result = await loop.run_in_executor(None, _locked_blocking_run)
        except Exception as exc:
            logging.getLogger(LOGGER_NAME).exception("Job failed: %s", exc)
            await event_sink.drain()
            await self._send_event(websocket, "event.final", {"jobId": job_id, "status": "fail", "error": str(exc)})
            return
        finally:
            # Ensure job is always removed from manager
            jobs.remove(job_id)
            approval.cancel_all()
            with self._approval_lock:
                self._approval_adapters.pop(job_id, None)

        await event_sink.drain()
        await self._send_event(websocket, "event.final", {"jobId": job_id, **result})
        self._logger.info("agent.run completed job=%s status=%s", job_id, result.get("status"))

    def _create_session(
        self,
        provider: Optional[str],
        api_key: Optional[str] = None,
        provider_options: Optional[dict[str, dict[str, str | None]]] = None,
    ) -> tuple[str, LLMClient, ToolRegistry, CompositeToolGateway]:
        p = provider or _DEFAULT_PROVIDER
        provider_options = provider_options or {}
        options = {
            k: v
            for k, v in provider_options.get(p, {}).items()
            if isinstance(v, str) and v
        }
        inj = _create_container(provider, api_key=api_key, provider_options=options)
        client = inj.get(LLMClient)
        tools = inj.get(ToolRegistry)
        try:
            tool_gateway = inj.get(CompositeToolGateway)
        except Exception:
            tool_gateway = CompositeToolGateway([LocalComputerToolProvider(tools)])
        session_id = str(uuid.uuid4())
        return session_id, client, tools, tool_gateway

    def _normalize_session(self, session: tuple) -> tuple[str, LLMClient, ToolRegistry, CompositeToolGateway]:
        if len(session) == 4:
            return session  # type: ignore[return-value]
        session_id, client, tools = session
        return session_id, client, tools, CompositeToolGateway([LocalComputerToolProvider(tools)])

    async def _send_result(self, websocket: WebSocket, req_id: Any, result: Dict[str, Any]) -> None:
        payload = {"jsonrpc": "2.0", "id": req_id, "result": result}
        await websocket.send_text(self._dumps(payload))

    async def _send_error(self, websocket: WebSocket, req_id: Any, code: int, message: str, data: Optional[Dict[str, Any]] = None) -> None:
        err = {"code": code, "message": message}
        if data is not None:
            err["data"] = data
        payload = {"jsonrpc": "2.0", "id": req_id, "error": err}
        await websocket.send_text(self._dumps(payload))

    async def _send_event(self, websocket: WebSocket, method: str, params: Dict[str, Any]) -> None:
        try:
            payload = {"jsonrpc": "2.0", "method": method, "params": params}
            await websocket.send_text(self._dumps(payload))
        except Exception as e:
            # WebSocket might be closed, log but don't crash
            self._logger.debug("Failed to send event %s: %s", method, e)

    def _dumps(self, obj: Any) -> str:
        result = json.dumps(obj)
        return result.decode() if isinstance(result, bytes) else result  # type: ignore[union-attr]



def _create_container(provider: Optional[str] = None, api_key: Optional[str] = None, provider_options: Optional[dict[str, str]] = None):
    # Lazy import to avoid hard dependency at import time (helps tests/CI without injector installed)
    from os_ai_core.di import create_container as _cc  # type: ignore
    return _cc(provider, api_key=api_key, provider_options=provider_options)


def _application_runner_enabled() -> bool:
    return os.environ.get("OS_AI_USE_APPLICATION_RUNNER", "1").lower() not in {"0", "false", "no", "off"}
