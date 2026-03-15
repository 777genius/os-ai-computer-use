from __future__ import annotations

import os, time, random, logging
from typing import Any, Dict, List, Optional
import json

import anthropic
import httpx

from os_ai_llm_anthropic.config import (
    MODEL_NAME,
    COMPUTER_TOOL_TYPE,
    COMPUTER_BETA_FLAG,
)
from os_ai_llm.config import (
    API_REQUEST_TIMEOUT_SECONDS,
    API_MAX_RETRIES,
    API_BACKOFF_BASE_SECONDS,
    API_BACKOFF_MAX_SECONDS,
    API_BACKOFF_JITTER_SECONDS,
)
from os_ai_core.config import LOGGER_NAME
from os_ai_llm.interfaces import LLMClient
from os_ai_llm.types import (
    ContentPart,
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


class AnthropicClient(LLMClient):
    def __init__(self, api_key: Optional[str] = None, model_name: Optional[str] = None) -> None:
        key = api_key or os.environ.get("ANTHROPIC_API_KEY")
        if not key:
            raise RuntimeError("ANTHROPIC_API_KEY is not set")
        try:
            self._client = anthropic.Anthropic(api_key=key, max_retries=0, timeout=httpx.Timeout(float(API_REQUEST_TIMEOUT_SECONDS)))  # type: ignore
        except Exception:
            self._client = anthropic.Anthropic(api_key=key)
        self._model = model_name or MODEL_NAME

    def get_model_name(self) -> str:
        return self._model

    def get_provider_name(self) -> str:
        return "anthropic"

    def _to_provider_messages(self, messages: List[Message]) -> List[Dict[str, Any]]:
        out: List[Dict[str, Any]] = []
        for m in messages:
            blocks: List[Dict[str, Any]] = []
            for p in m.content:
                if isinstance(p, ProviderPart) and p.provider == "anthropic":
                    if isinstance(p.data, list):
                        blocks.extend(p.data)
                    elif isinstance(p.data, dict):
                        blocks.append(p.data)
                    continue
                elif isinstance(p, TextPart):
                    blocks.append({"type": "text", "text": p.text})
                elif isinstance(p, ImagePart):
                    blocks.append({
                        "type": "image",
                        "source": {"type": "base64", "media_type": p.media_type, "data": p.data_base64},
                    })
                # ProviderPart from other providers — silently skip
            out.append({"role": m.role, "content": blocks})
        return out

    def _to_provider_tools(self, tools: List[ToolDescriptor]) -> List[Dict[str, Any]]:
        out: List[Dict[str, Any]] = []
        for t in tools:
            if t.kind == "computer_use":
                params = dict(t.params)
                out.append({
                    "type": params.get("type", COMPUTER_TOOL_TYPE),
                    "name": t.name,
                    "display_width_px": params.get("display_width_px"),
                    "display_height_px": params.get("display_height_px"),
                })
            else:
                out.append({"type": "tool", "name": t.name})
        return out

    def _parse_tool_calls(self, content: Any) -> List[ToolCall]:
        calls: List[ToolCall] = []
        for block in content or []:
            if getattr(block, "type", None) == "tool_use":
                name = getattr(block, "name", "")
                args = getattr(block, "input", {}) or {}
                id_ = getattr(block, "id", "")
                calls.append(ToolCall(id=id_, name=name, args=args))
        return calls

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
        provider_messages = self._to_provider_messages(messages)
        provider_tools = self._to_provider_tools(tools)

        # Ensure computer tool inputs get default coordinate_space="auto"
        patched_messages = []
        for m in provider_messages:
            if m.get("role") == "assistant":
                patched_messages.append(m)
                continue
            new_blocks: List[Dict[str, Any]] = []
            for b in m.get("content", []) or []:
                if isinstance(b, dict) and b.get("type") == "tool_result":
                    try:
                        cnt = []
                        for c in b.get("content", []) or []:
                            if isinstance(c, dict) and c.get("type") == "text":
                                cnt.append(c)
                            elif isinstance(c, dict) and c.get("type") == "image":
                                cnt.append(c)
                        b = {"type": "tool_result", "tool_use_id": b.get("tool_use_id"), "content": cnt, "is_error": bool(b.get("is_error"))}
                    except Exception:
                        pass
                new_blocks.append(b)
            patched_messages.append({"role": m.get("role"), "content": new_blocks})

        logger = logging.getLogger(LOGGER_NAME)
        resp = None
        last_err: Exception | None = None
        for attempt in range(1, int(API_MAX_RETRIES) + 1):
            try:
                resp = self._client.beta.messages.create(
                    model=self._model,
                    max_tokens=int(max_tokens),
                    tools=provider_tools,
                    messages=patched_messages,
                    betas=[COMPUTER_BETA_FLAG],
                    system=system,
                    tool_choice={
                        "type": tool_choice,
                        "disable_parallel_tool_use": (not bool(allow_parallel_tools)),
                    },
                    timeout=API_REQUEST_TIMEOUT_SECONDS,
                )
                break
            except httpx.HTTPStatusError as e:
                last_err = e
                status = getattr(e.response, "status_code", None)
                if status == 429 and attempt < int(API_MAX_RETRIES):
                    retry_after_hdr = None
                    try:
                        retry_after_hdr = e.response.headers.get("retry-after")
                    except Exception:
                        retry_after_hdr = None
                    if retry_after_hdr:
                        try:
                            backoff = float(retry_after_hdr)
                        except Exception:
                            backoff = float(API_BACKOFF_BASE_SECONDS)
                    else:
                        backoff = min(
                            float(API_BACKOFF_MAX_SECONDS),
                            float(API_BACKOFF_BASE_SECONDS) * (2 ** (attempt - 1)) + random.uniform(0, float(API_BACKOFF_JITTER_SECONDS)),
                        )
                    try:
                        logger.warning(f"Rate limited (429). Attempt {attempt}/{int(API_MAX_RETRIES)-1}. Waiting {backoff:.2f}s before retry...")
                    except Exception:
                        pass
                    time.sleep(backoff)
                    continue
                try:
                    body = None
                    try:
                        body = e.response.json()
                    except Exception:
                        body = e.response.text
                    logger.error(f"HTTP {status} from Anthropic: {body}")
                except Exception:
                    pass
                raise
            except Exception as e:
                last_err = e
                raise
        if resp is None and last_err is not None:
            raise last_err

        # Convert assistant message content — use ProviderPart instead of text markers
        assistant_texts: List[str] = []
        tool_use_blocks: List[Dict[str, Any]] = []
        for b in resp.content:
            btype = getattr(b, "type", None)
            if btype == "text":
                assistant_texts.append(getattr(b, "text", ""))
            elif btype == "tool_use":
                tool_use_blocks.append({
                    "type": "tool_use",
                    "id": getattr(b, "id", ""),
                    "name": getattr(b, "name", ""),
                    "input": getattr(b, "input", {}) or {},
                })

        assistant_parts: List[ContentPart] = [TextPart(text=t) for t in assistant_texts if t]
        if tool_use_blocks:
            assistant_parts.append(ProviderPart(provider="anthropic", sub_type="tool_use", data=tool_use_blocks))
        assistant_msg = Message(role="assistant", content=assistant_parts)

        tool_calls = self._parse_tool_calls(resp.content)

        # Usage mapping
        in_tokens = 0
        out_tokens = 0
        try:
            usage = getattr(resp, "usage", None)
            if usage is not None:
                in_tokens = int(getattr(usage, "input_tokens", 0) or 0)
                out_tokens = int(getattr(usage, "output_tokens", 0) or 0)
        except Exception:
            pass

        return LLMResponse(
            messages=[assistant_msg],
            tool_calls=tool_calls,
            usage=Usage(input_tokens=in_tokens, output_tokens=out_tokens, provider_raw={"input_tokens": in_tokens, "output_tokens": out_tokens}),
        )

    def format_tool_result(self, result: ToolResult) -> Message:
        blocks: List[Dict[str, Any]] = [
            {
                "type": "tool_result",
                "tool_use_id": result.tool_call_id,
                "content": [
                    (
                        {"type": "text", "text": p.text}
                        if isinstance(p, TextPart)
                        else {
                            "type": "image",
                            "source": {"type": "base64", "media_type": p.media_type, "data": p.data_base64},
                        }
                    )
                    for p in result.content
                    if isinstance(p, (TextPart, ImagePart))
                ],
                "is_error": bool(result.is_error),
            }
        ]
        return Message(role="user", content=[ProviderPart(
            provider="anthropic", sub_type="tool_result", data=blocks,
        )])
