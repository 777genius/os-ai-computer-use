from __future__ import annotations

from typing import Optional

import injector

from config.settings import LLM_PROVIDER
from llm.interfaces import LLMClient
from tools.registry import ToolRegistry
from tools.computer import computer_tool_handler_batch


class LLMModule(injector.Module):
    def __init__(self, provider: Optional[str] = None, api_key: Optional[str] = None) -> None:
        self._provider = (provider or LLM_PROVIDER).lower()
        self._api_key = api_key

    @injector.provider
    def provide_llm_client(self) -> LLMClient:  # type: ignore[override]
        if self._provider == "openai":
            from llm.adapters_openai import OpenAIClient
            return OpenAIClient(api_key=self._api_key)
        elif self._provider == "anthropic":
            from llm.adapters_anthropic import AnthropicClient
            return AnthropicClient(api_key=self._api_key)
        else:
            raise ValueError(f"Unknown LLM provider: '{self._provider}'. Supported: 'anthropic', 'openai'")


class ToolsModule(injector.Module):
    @injector.provider
    def provide_tool_registry(self) -> ToolRegistry:  # type: ignore[override]
        reg = ToolRegistry()
        reg.register("computer", computer_tool_handler_batch)
        return reg


def create_container(provider: Optional[str] = None, api_key: Optional[str] = None) -> injector.Injector:
    return injector.Injector([LLMModule(provider, api_key=api_key), ToolsModule()])
