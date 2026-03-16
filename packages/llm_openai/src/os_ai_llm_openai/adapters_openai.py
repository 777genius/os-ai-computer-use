"""OpenAI Computer Use adapter using Responses API.

Uses client.responses.create() with {"type": "computer"} tool.
Supports previous_response_id for server-side conversation state.
Handles batched actions and safety checks.
"""

from __future__ import annotations

import os
import logging
from typing import Any, Dict, List, Optional

import httpx
from openai import OpenAI, RateLimitError, APIStatusError, APIConnectionError, APITimeoutError

from os_ai_llm_openai.config import (
    OPENAI_MODEL_NAME,
    OPENAI_API_TIMEOUT_SECONDS,
    OPENAI_API_MAX_RETRIES,
    OPENAI_REASONING_SUMMARY,
    OPENAI_SCREENSHOT_DETAIL,
    OPENAI_AUTO_ACKNOWLEDGE_SAFETY_CHECKS,
)
from os_ai_llm_openai.action_converter import openai_action_to_internal, _extract_coord
from os_ai_llm.interfaces import LLMClient
from os_ai_llm.types import (
    Message,
    ToolDescriptor,
    LLMResponse,
    ToolResult,
    Usage,
    TextPart,
    ImagePart,
    ToolCall,
    ProviderPart,
)

LOGGER_NAME = "os_ai"


class OpenAIClient(LLMClient):
    """OpenAI Computer Use adapter via Responses API."""

    def __init__(self, api_key: Optional[str] = None, model_name: Optional[str] = None) -> None:
        key = api_key or os.environ.get("OPENAI_API_KEY")
        if not key:
            raise RuntimeError(
                "OPENAI_API_KEY is not set. "
                "Provide it via the app Settings or set the OPENAI_API_KEY environment variable."
            )
        self._client = OpenAI(
            api_key=key,
            timeout=httpx.Timeout(float(OPENAI_API_TIMEOUT_SECONDS)),
            max_retries=OPENAI_API_MAX_RETRIES,
        )
        self._model = model_name or OPENAI_MODEL_NAME

    def get_model_name(self) -> str:
        return self._model

    def get_provider_name(self) -> str:
        return "openai"

    # ---- Input construction ----

    def _build_initial_input(self, messages: List[Message], system: Optional[str]) -> List[Any]:
        """Build Responses API input from canonical messages (first call, no previous_response_id)."""
        input_items: List[Any] = []
        for m in messages:
            if m.role == "system":
                continue  # system goes to 'instructions' parameter

            # Content type depends on role: user→input_text, assistant→output_text
            text_type = "output_text" if m.role == "assistant" else "input_text"

            parts: List[Dict[str, Any]] = []
            for p in m.content:
                if isinstance(p, TextPart):
                    parts.append({"type": text_type, "text": p.text})
                elif isinstance(p, ImagePart):
                    data_uri = f"data:{p.media_type};base64,{p.data_base64}"
                    parts.append({
                        "type": "input_image",
                        "image_url": data_uri,
                        "detail": OPENAI_SCREENSHOT_DETAIL,
                    })
                elif isinstance(p, ProviderPart) and p.provider == "openai":
                    if isinstance(p.data, list):
                        input_items.extend(p.data)
                    elif isinstance(p.data, dict):
                        input_items.append(p.data)
                    continue

            if parts:
                input_items.append({
                    "role": m.role if m.role in ("user", "assistant") else "user",
                    "content": parts,
                })

        return input_items

    def _build_tool_result_input(self, messages: List[Message]) -> List[Any]:
        """Collect NEW input items added AFTER the last assistant message.

        With previous_response_id the server already has older context,
        so we only send items that appeared since the last assistant turn:
        user text, images, and computer_call_output results.
        """
        last_assistant_idx = -1
        for i, m in enumerate(messages):
            if m.role == "assistant":
                last_assistant_idx = i

        items: List[Any] = []
        for m in messages[last_assistant_idx + 1:]:
            parts: List[Dict[str, Any]] = []
            for p in m.content:
                if isinstance(p, TextPart):
                    parts.append({"type": "input_text", "text": p.text})
                elif isinstance(p, ImagePart):
                    data_uri = f"data:{p.media_type};base64,{p.data_base64}"
                    parts.append({
                        "type": "input_image",
                        "image_url": data_uri,
                        "detail": OPENAI_SCREENSHOT_DETAIL,
                    })
                elif isinstance(p, ProviderPart) and p.provider == "openai":
                    if isinstance(p.data, dict):
                        items.append(p.data)
                    elif isinstance(p.data, list):
                        items.extend(p.data)
            if parts:
                items.append({
                    "role": m.role if m.role in ("user",) else "user",
                    "content": parts,
                })
        return items

    # ---- Response parsing ----

    def _parse_response(self, resp: Any) -> LLMResponse:
        """Parse OpenAI Responses API response into canonical LLMResponse."""
        logger = logging.getLogger(LOGGER_NAME)

        assistant_parts: List[Any] = []
        tool_calls: List[ToolCall] = []

        for item in (resp.output or []):
            item_type = getattr(item, "type", "")

            if item_type == "message":
                for content_block in getattr(item, "content", []):
                    block_type = getattr(content_block, "type", "")
                    if block_type == "output_text":
                        text = getattr(content_block, "text", "")
                        if text.strip():
                            assistant_parts.append(TextPart(text=text))

            elif item_type == "computer_call":
                call_id = getattr(item, "call_id", "")
                actions_raw = getattr(item, "actions", None) or []
                pending_safety = getattr(item, "pending_safety_checks", None) or []

                internal_actions = []
                for action_obj in actions_raw:
                    action_dict = self._sdk_action_to_dict(action_obj)
                    if action_dict:
                        internal_actions.append(openai_action_to_internal(action_dict))

                first_action = internal_actions[0] if internal_actions else {"action": "screenshot"}

                safety_list = [
                    {"id": getattr(sc, "id", ""), "code": getattr(sc, "code", ""), "message": getattr(sc, "message", "")}
                    for sc in pending_safety
                ]

                tool_calls.append(ToolCall(
                    id=call_id,
                    name="computer",
                    args=first_action,
                    metadata={
                        "_openai_batch": True,
                        "_openai_actions": internal_actions,
                        "_openai_pending_safety_checks": safety_list,
                    },
                ))

            elif item_type == "reasoning":
                for s in (getattr(item, "summary", None) or []):
                    text = getattr(s, "text", "")
                    if text:
                        logger.debug("🤔 Reasoning: %s", text[:300])

        if not assistant_parts and not tool_calls:
            assistant_parts.append(TextPart(text=""))

        assistant_msg = Message(role="assistant", content=assistant_parts)

        in_tokens = 0
        out_tokens = 0
        try:
            usage = getattr(resp, "usage", None)
            if usage:
                in_tokens = int(getattr(usage, "input_tokens", 0) or 0)
                out_tokens = int(getattr(usage, "output_tokens", 0) or 0)
        except Exception:
            pass

        return LLMResponse(
            messages=[assistant_msg],
            tool_calls=tool_calls,
            usage=Usage(input_tokens=in_tokens, output_tokens=out_tokens,
                        provider_raw={"input_tokens": in_tokens, "output_tokens": out_tokens}),
            provider_context={"previous_response_id": getattr(resp, "id", None)},
        )

    @staticmethod
    def _sdk_action_to_dict(action_obj: Any) -> Optional[Dict[str, Any]]:
        """Convert SDK Pydantic action object to plain dict."""
        if isinstance(action_obj, dict):
            return action_obj
        if not hasattr(action_obj, "type"):
            return None
        d: Dict[str, Any] = {"type": getattr(action_obj, "type", "")}
        for field in ("x", "y", "button", "text", "keys", "scroll_x", "scroll_y"):
            val = getattr(action_obj, field, None)
            if val is not None:
                if field == "keys" and val:
                    d["keys"] = list(val)
                else:
                    d[field] = val
        path = getattr(action_obj, "path", None)
        if path is not None:
            d["path"] = [{"x": _extract_coord(pt, "x"), "y": _extract_coord(pt, "y")} for pt in path]
        return d

    # ---- Main generate method ----

    def generate(
        self,
        messages: List[Message],
        tools: List[ToolDescriptor],
        system: Optional[str] = None,
        tool_choice: str = "auto",
        max_tokens: int = 1024,
        allow_parallel_tools: bool = True,
        provider_context: Optional[Dict[str, Any]] = None,
    ) -> LLMResponse:
        logger = logging.getLogger(LOGGER_NAME)

        provider_tools: List[Dict[str, Any]] = []
        for t in tools:
            if t.kind == "computer_use":
                provider_tools.append({"type": "computer"})

        previous_response_id = None
        if provider_context:
            previous_response_id = provider_context.get("previous_response_id")

        if previous_response_id:
            input_data = self._build_tool_result_input(messages)
        else:
            input_data = self._build_initial_input(messages, system)

        if not input_data:
            logger.warning("OpenAI input_data is empty — this likely indicates a bug in message building. "
                           "Messages count: %d, previous_response_id: %s", len(messages), previous_response_id)
            input_data = [{"role": "user", "content": [{"type": "input_text", "text": "Continue."}]}]

        kwargs: Dict[str, Any] = {
            "model": self._model,
            "tools": provider_tools,
            "input": input_data,
        }

        if previous_response_id:
            kwargs["previous_response_id"] = previous_response_id
        # Instructions do NOT carry over with previous_response_id — must re-send every time
        if system:
            kwargs["instructions"] = system
        if self._model.startswith("gpt-5"):
            kwargs["reasoning"] = {"summary": OPENAI_REASONING_SUMMARY}

        logger.debug("OpenAI request: model=%s, previous_response_id=%s, input_type=%s, input_len=%s",
                      self._model, previous_response_id, type(input_data).__name__,
                      len(input_data) if isinstance(input_data, list) else "str")

        try:
            resp = self._client.responses.create(**kwargs)
        except APIStatusError as e:
            # Fallback: if previous_response_id expired/invalid, retry without it
            if previous_response_id and e.status_code in (400, 404):
                logger.warning("previous_response_id rejected (%s), falling back to full context", e.status_code)
                kwargs.pop("previous_response_id", None)
                kwargs["input"] = self._build_initial_input(messages, system)
                try:
                    resp = self._client.responses.create(**kwargs)
                except Exception as retry_err:
                    logger.error("OpenAI retry without previous_response_id failed: %s", retry_err)
                    return LLMResponse(
                        messages=[Message(role="assistant", content=[TextPart(text=f"API error: {retry_err}")])],
                        tool_calls=[], usage=Usage(),
                    )
            else:
                logger.error("OpenAI API error %s: %s", e.status_code, e.message)
                return LLMResponse(
                    messages=[Message(role="assistant", content=[TextPart(text=f"API error: {e.message}")])],
                    tool_calls=[], usage=Usage(),
                )
        except RateLimitError as e:
            logger.error("Rate limited by OpenAI (retries exhausted): %s", e)
            return LLMResponse(
                messages=[Message(role="assistant", content=[TextPart(text=f"Rate limited: {e}")])],
                tool_calls=[], usage=Usage(),
                provider_context={"previous_response_id": provider_context.get("previous_response_id") if provider_context else None},
            )
        except (APIConnectionError, APITimeoutError) as e:
            logger.error("OpenAI connection/timeout: %s", e)
            return LLMResponse(
                messages=[Message(role="assistant", content=[TextPart(text=f"Connection error: {e}")])],
                tool_calls=[], usage=Usage(),
            )

        return self._parse_response(resp)

    # ---- Tool result formatting ----

    def format_tool_result(self, result: ToolResult) -> Message:
        """Format tool result as OpenAI computer_call_output."""
        logger = logging.getLogger(LOGGER_NAME)

        screenshot_b64 = ""
        media_type = "image/png"

        for p in result.content:
            if isinstance(p, ImagePart):
                screenshot_b64 = p.data_base64
                media_type = p.media_type

        if not screenshot_b64:
            logger.warning("No screenshot in tool result — OpenAI requires one. Check tool handler.")

        output_item: Dict[str, Any] = {
            "type": "computer_call_output",
            "call_id": result.tool_call_id,
            "output": {
                "type": "computer_screenshot",
                "image_url": f"data:{media_type};base64,{screenshot_b64}" if screenshot_b64 else "",
            },
        }

        pending_checks = result.metadata.get("_openai_pending_safety_checks", [])
        if pending_checks and OPENAI_AUTO_ACKNOWLEDGE_SAFETY_CHECKS:
            output_item["acknowledged_safety_checks"] = [
                {"id": sc.get("id", ""), "code": sc.get("code", ""), "message": sc.get("message", "")}
                for sc in pending_checks
            ]

        return Message(
            role="user",
            content=[ProviderPart(
                provider="openai",
                sub_type="computer_call_output",
                data=output_item,
            )],
        )
