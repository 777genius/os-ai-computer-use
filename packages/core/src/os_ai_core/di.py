from __future__ import annotations

from typing import Optional

import injector

from os_ai_llm.config import LLM_PROVIDER
from os_ai_llm.interfaces import LLMClient
from os_ai_llm_anthropic.adapters_anthropic import AnthropicClient
from os_ai_llm_openai.adapters_openai import OpenAIClient
from os_ai_core.tools.registry import ToolRegistry
from os_ai_core.tools.computer import computer_tool_handler


class LLMModule(injector.Module):
    def __init__(self, provider: Optional[str] = None, api_key: Optional[str] = None) -> None:
        self._provider = (provider or LLM_PROVIDER).lower()
        self._api_key = api_key

    @injector.provider
    def provide_llm_client(self) -> LLMClient:  # type: ignore[override]
        if self._provider == "openai":
            return OpenAIClient(api_key=self._api_key)
        return AnthropicClient(api_key=self._api_key)


class ToolsModule(injector.Module):
    @injector.provider
    def provide_tool_registry(self) -> ToolRegistry:  # type: ignore[override]
        reg = ToolRegistry()
        reg.register("computer", computer_tool_handler)
        return reg


def create_container(provider: Optional[str] = None, api_key: Optional[str] = None) -> injector.Injector:
    return injector.Injector([LLMModule(provider, api_key=api_key), ToolsModule()])


