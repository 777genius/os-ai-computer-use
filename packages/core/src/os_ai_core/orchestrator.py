from __future__ import annotations

from typing import List, Optional, Callable, Dict, Any
import logging, json, sys
import httpx

from os_ai_llm.interfaces import LLMClient
from os_ai_llm.types import Message, ToolDescriptor, TextPart, ToolCall, ToolResult, ImagePart
from os_ai_core.utils.costs import estimate_cost
from os_ai_core.config import USAGE_LOG_EACH_ITERATION, LOGGER_NAME
from os_ai_core.tools.registry import ToolRegistry


class CancelToken:
    def __init__(self) -> None:
        self._cancelled = False

    def cancel(self) -> None:
        self._cancelled = True

    @property
    def is_cancelled(self) -> bool:
        return self._cancelled


class Orchestrator:
    def __init__(self, client: LLMClient, tool_registry: ToolRegistry) -> None:
        self._client = client
        self._tools = tool_registry
        self.total_input_tokens: int = 0
        self.total_output_tokens: int = 0

    def run(
        self,
        task: str,
        tool_descriptors: List[ToolDescriptor],
        system: Optional[str],
        max_iterations: int = 30,
        *,
        cancel_token: Optional[CancelToken] = None,
        on_event: Optional[Callable[[str, Dict[str, Any]], None]] = None,
        initial_messages: Optional[List[Message]] = None,
    ) -> List[Message]:
        messages: List[Message] = []
        try:
            if initial_messages:
                messages.extend(initial_messages)
        except Exception:
            pass
        messages.append(Message(role="user", content=[TextPart(text=task)]))
        logger = logging.getLogger(LOGGER_NAME)
        provider_context: Optional[Dict[str, Any]] = None
        try:
            self.total_input_tokens = 0
            self.total_output_tokens = 0
        except Exception:
            pass
        for iter_idx in range(max_iterations):
            if cancel_token is not None and cancel_token.is_cancelled:
                if on_event is not None:
                    try:
                        on_event("progress", {"stage": "cancelled", "iteration": iter_idx})
                    except Exception:
                        pass
                break
            if on_event is not None:
                try:
                    on_event("progress", {"stage": "iteration_start", "iteration": iter_idx})
                except Exception:
                    pass
            try:
                resp = self._client.generate(
                    messages=messages,
                    tools=tool_descriptors,
                    system=system,
                    provider_context=provider_context,
                )
            except httpx.HTTPStatusError as e:
                status = getattr(e.response, "status_code", None)
                provider = "provider"
                try:
                    provider = self._client.get_provider_name()
                except Exception:
                    pass
                try:
                    body = e.response.json()
                except Exception:
                    body = e.response.text
                logger.error(f"HTTP {status} from {provider}: {body}")
                break
            except (httpx.ReadTimeout, httpx.ConnectTimeout, httpx.WriteTimeout) as e:
                logger.error(f"HTTP timeout from provider: {e}")
                break
            except Exception as e:
                logger.error(f"Provider error: {e}")
                break

            # Save provider context for next iteration
            provider_context = resp.provider_context

            # Print assistant texts immediately (deduplicated)
            _seen_texts: set = set()
            try:
                for m in resp.messages or []:
                    if getattr(m, "role", None) == "assistant":
                        for p in (getattr(m, "content", []) or []):
                            try:
                                if getattr(p, "type", None) == "text":
                                    txt = str(getattr(p, "text", "")).strip()
                                    if txt and txt not in _seen_texts:
                                        _seen_texts.add(txt)
                                        logger.info('🧠 %s', txt)
                                        if on_event is not None:
                                            try:
                                                on_event("assistant_text", {"text": txt})
                                            except Exception:
                                                pass
                            except Exception:
                                pass
            except Exception:
                pass
            # Usage/cost logging
            try:
                inp = int(getattr(resp.usage, "input_tokens", 0) or 0)
                out = int(getattr(resp.usage, "output_tokens", 0) or 0)
                try:
                    self.total_input_tokens += inp
                    self.total_output_tokens += out
                except Exception:
                    pass
                if on_event is not None:
                    try:
                        try:
                            _model = self._client.get_model_name()
                        except Exception:
                            _model = "unknown"
                        _ic, _oc, _tc, _tier = estimate_cost(_model, inp, out)
                        on_event("usage", {
                            "input_tokens": inp,
                            "output_tokens": out,
                            "iteration": iter_idx,
                            "total_input_tokens": int(self.total_input_tokens),
                            "total_output_tokens": int(self.total_output_tokens),
                            "input_cost": _ic,
                            "output_cost": _oc,
                            "total_cost": _tc,
                        })
                    except Exception:
                        pass
                if USAGE_LOG_EACH_ITERATION:
                    try:
                        model_name = self._client.get_model_name()
                    except Exception:
                        model_name = "unknown"
                    _in_cost, _out_cost, _total, _tier = estimate_cost(model_name, inp, out)
                    logger.info("📈 Usage iter in=%s out=%s cost=$%.6f (input=$%.6f, output=$%.6f)", inp, out, (_in_cost + _out_cost), _in_cost, _out_cost)
            except Exception:
                pass

            # Append assistant message
            if resp.messages:
                messages.extend(resp.messages)

            if not resp.tool_calls:
                break

            # Execute tool calls sequentially
            for call in resp.tool_calls:
                if cancel_token is not None and cancel_token.is_cancelled:
                    break
                if on_event is not None:
                    try:
                        batch_actions = call.metadata.get("_openai_actions")
                        if batch_actions and len(batch_actions) > 1:
                            # Emit single summary for batch, then each action
                            action_names = [a.get("action", "?") for a in batch_actions]
                            summary = ", ".join(action_names)
                            on_event("tool_call", {"name": call.name, "args": {"action": f"batch ({len(batch_actions)}): {summary}"}})
                        else:
                            on_event("tool_call", {"name": call.name, "args": call.args})
                    except Exception:
                        pass
                result = self._tools.execute(call)
                # Propagate provider metadata (safety checks, etc.)
                safety_checks = call.metadata.get("_openai_pending_safety_checks", [])
                if safety_checks:
                    result.metadata["_openai_pending_safety_checks"] = safety_checks
                # Emit result events
                if on_event is not None:
                    try:
                        has_image = any(isinstance(p, ImagePart) for p in result.content)
                        if has_image:
                            for p in result.content:
                                if isinstance(p, ImagePart):
                                    on_event("tool_result_image", {"media_type": p.media_type, "data": p.data_base64})
                        else:
                            for p in result.content:
                                if getattr(p, "type", None) == "text" or type(p).__name__ == "TextPart":
                                    on_event("tool_result_text", {"text": getattr(p, "text", "")})
                                    break
                    except Exception:
                        pass
                # Append formatted tool result to history
                messages.append(self._client.format_tool_result(result))

        return messages
