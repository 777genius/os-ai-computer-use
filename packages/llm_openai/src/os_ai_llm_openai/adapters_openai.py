from __future__ import annotations

import os
from typing import Any, Dict, List, Optional

from os_ai_llm_openai.config import OPENAI_MODEL_NAME
from os_ai_llm.interfaces import LLMClient
from os_ai_llm.types import Message, ToolDescriptor, LLMResponse, ToolResult, Usage, TextPart, ImagePart, ToolCall


class OpenAIClient(LLMClient):
    """OpenAI Computer Use adapter via Responses API. Stub — full implementation in Iteration 2."""

    def __init__(self, api_key: Optional[str] = None, model_name: Optional[str] = None) -> None:
        key = api_key or os.environ.get("OPENAI_API_KEY")
        if not key:
            raise RuntimeError("OPENAI_API_KEY is not set")
        self._api_key = key
        self._model = model_name or OPENAI_MODEL_NAME

    def get_model_name(self) -> str:
        return self._model

    def get_provider_name(self) -> str:
        return "openai"

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
        assistant = Message(role="assistant", content=[TextPart(text="OpenAI adapter not implemented yet.")])
        return LLMResponse(messages=[assistant], tool_calls=[], usage=Usage())

    def format_tool_result(self, result: ToolResult) -> Message:
        txts = []
        for p in result.content:
            if isinstance(p, TextPart):
                txts.append(p.text)
            elif isinstance(p, ImagePart):
                txts.append(f"[image {p.media_type} {len(p.data_base64)}b]")
        return Message(role="tool", content=[TextPart(text=f"TOOL({result.tool_call_id}):\n" + "\n".join(txts))])
