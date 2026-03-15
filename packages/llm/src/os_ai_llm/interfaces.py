from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Any, Dict, List, Optional

from .types import Message, ToolDescriptor, LLMResponse, ToolResult


class LLMClient(ABC):
    """Provider-agnostic LLM client interface."""

    @abstractmethod
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
        """Produce an assistant response and optional tool calls.

        Args:
            provider_context: Opaque state from previous LLMResponse.provider_context.
                             Allows providers to maintain state between calls
                             (e.g., OpenAI's previous_response_id).
        """

    @abstractmethod
    def format_tool_result(self, result: ToolResult) -> Message:
        """Format a provider-specific tool-result message to append to history."""

    def get_model_name(self) -> str:
        """Return the model name used by this client."""
        return "unknown"

    def get_provider_name(self) -> str:
        """Return the provider identifier ('anthropic', 'openai', etc.)."""
        return "unknown"
