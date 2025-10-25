from __future__ import annotations

import asyncio
import logging
import uuid
from typing import Any, Dict, Optional

import httpx
from fastapi import WebSocket

try:
    import orjson as json  # type: ignore
except Exception:  # pragma: no cover - fallback if orjson not available
    import json  # type: ignore

from os_ai_llm.types import ToolDescriptor
from os_ai_core.orchestrator import Orchestrator, CancelToken

from os_ai_llm.interfaces import LLMClient
from os_ai_core.tools.registry import ToolRegistry

import pyautogui

from os_ai_llm_anthropic.config import COMPUTER_TOOL_TYPE
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

    async def handle(self, websocket: WebSocket) -> None:
        # Extract API key from WebSocket query parameters (sent by frontend)
        # Store in local variable to avoid race conditions between concurrent connections
        query_params = websocket.query_params
        api_key = query_params.get('anthropic_api_key')

        if api_key:
            self._logger.info("API key provided via WebSocket query params")
        else:
            self._logger.info("No API key in WebSocket params, will use environment variable")

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
                    try:
                        session_id, client, tools = self._create_session(provider, api_key=api_key)
                        self._logger.info("session.create -> %s (provider=%s)", session_id, provider or "default")
                        await self._send_result(websocket, req_id, {
                            "sessionId": session_id,
                            "capabilities": {"ws": True, "jsonrpc": True}
                        })
                    except RuntimeError as e:
                        self._logger.warning("session.create failed: %s", str(e))
                        await self._send_error(websocket, req_id, -32000,
                            "API key required. Please configure your Anthropic API key in Settings.")
                elif method == "agent.run":
                    task_text = params.get("task") or ""
                    if not task_text:
                        await self._send_error(websocket, req_id, -32602, "Missing 'task'")
                        continue
                    provider = params.get("provider")
                    max_iterations = int(params.get("maxIterations", 30))
                    initial_messages = params.get("context") or []
                    attachments = params.get("attachments") or []

                    # Build session and run orchestration in background
                    try:
                        session_id, client, tools = self._create_session(provider, api_key=api_key)
                    except RuntimeError as e:
                        self._logger.warning("agent.run failed: %s", str(e))
                        await self._send_error(websocket, req_id, -32000,
                            "API key required. Please configure your Anthropic API key in Settings.")
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
                        task_text=task_text,
                        max_iterations=max_iterations,
                        cancel=cancel_token,
                        initial_messages=initial_messages,
                        attachments=attachments,
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
        task_text: str,
        max_iterations: int,
        cancel: CancelToken,
        initial_messages: list | None = None,
        attachments: list | None = None,
    ) -> None:
        screen_w, screen_h = pyautogui.size()
        tool_descs = [
            ToolDescriptor(
                name="computer",
                kind="computer_use",
                params={
                    "type": COMPUTER_TOOL_TYPE,
                    "display_width_px": screen_w,
                    "display_height_px": screen_h,
                },
            )
        ]
        system_prompt = (
            "You are an expert desktop operator. Use the computer tool to complete the user's task. "
            "ONLY take a screenshot when needed. Prefer keyboard shortcuts. "
            "NEVER send empty key combos; always include a valid key or hotkey like 'cmd+space'. "
            "When using key/hold_key, provide 'key' or 'keys' as a non-empty string (e.g., 'cmd+space', 'ctrl+c'). "
            "For any action with coordinates, set coordinate_space='auto' in tool input."
        )

        orch = Orchestrator(client, tools)
        loop = asyncio.get_running_loop()

        def on_event(kind: str, payload: Dict[str, Any]) -> None:
            try:
                # Map orchestrator events to WS notifications
                if kind == "assistant_text":
                    # as log for now
                    asyncio.run_coroutine_threadsafe(self._send_event(websocket, "event.log", {"level": "info", "message": payload.get("text", ""), "jobId": job_id}), loop)
                elif kind == "tool_call":
                    asyncio.run_coroutine_threadsafe(self._send_event(websocket, "event.action", {"name": payload.get("name"), "status": "start", "meta": payload.get("args", {}), "jobId": job_id}), loop)
                elif kind == "tool_result_text":
                    asyncio.run_coroutine_threadsafe(self._send_event(websocket, "event.action", {"name": "tool_result", "status": "ok", "meta": payload, "jobId": job_id}), loop)
                elif kind == "tool_result_image":
                    asyncio.run_coroutine_threadsafe(self._send_event(websocket, "event.screenshot", {"mime": payload.get("media_type", "image/jpeg"), "data": payload.get("data", ""), "ts": None, "jobId": job_id}), loop)
                elif kind == "progress":
                    asyncio.run_coroutine_threadsafe(self._send_event(websocket, "event.progress", {**payload, "jobId": job_id}), loop)
                elif kind == "usage":
                    asyncio.run_coroutine_threadsafe(self._send_event(websocket, "event.usage", {**payload, "jobId": job_id}), loop)
            except Exception as e:
                self._logger.debug("Error in on_event %s: %s", kind, e)

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

            # Run orchestrator with auth error handling
            try:
                messages = orch.run(task_text, tool_descs, system_prompt, max_iterations=max_iterations, cancel_token=cancel, on_event=on_event, initial_messages=base_msgs)
            except httpx.HTTPStatusError as e:
                # Check for authentication/authorization errors
                if e.response.status_code in (401, 403):
                    raise RuntimeError(
                        "Invalid or expired API key. Please check your Anthropic API key in Settings and ensure it is valid."
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
                    "input_tokens": int(getattr(orch, "total_input_tokens", 0) or 0),
                    "output_tokens": int(getattr(orch, "total_output_tokens", 0) or 0),
                },
                "status": "ok",
            }

        try:
            result = await loop.run_in_executor(None, _blocking_run)
        except Exception as exc:
            logging.getLogger(LOGGER_NAME).exception("Job failed: %s", exc)
            await self._send_event(websocket, "event.final", {"jobId": job_id, "status": "fail", "error": str(exc)})
            return
        finally:
            # Ensure job is always removed from manager
            jobs.remove(job_id)

        await self._send_event(websocket, "event.final", {"jobId": job_id, **result})
        self._logger.info("agent.run completed job=%s status=%s", job_id, result.get("status"))

    def _create_session(self, provider: Optional[str], api_key: Optional[str] = None) -> tuple[str, LLMClient, ToolRegistry]:
        inj = _create_container(provider, api_key=api_key)
        client = inj.get(LLMClient)
        tools = inj.get(ToolRegistry)
        session_id = str(uuid.uuid4())
        return session_id, client, tools

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
        try:
            return json.dumps(obj).decode()  # type: ignore[attr-defined]
        except Exception:
            return json.dumps(obj)  # type: ignore[no-any-return]



def _create_container(provider: Optional[str] = None, api_key: Optional[str] = None):
    # Lazy import to avoid hard dependency at import time (helps tests/CI without injector installed)
    from os_ai_core.di import create_container as _cc  # type: ignore
    return _cc(provider, api_key=api_key)

