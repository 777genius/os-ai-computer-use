from __future__ import annotations

import logging
import os
from typing import Optional

import injector

from os_ai_llm.config import LLM_PROVIDER
from os_ai_llm.interfaces import LLMClient
from os_ai_core.adapters.tools.composite_tool_gateway import CompositeToolGateway
from os_ai_core.adapters.tools.computer_specs import build_computer_tool_descriptor
from os_ai_core.adapters.tools.local_computer_provider import LocalComputerToolProvider
from os_ai_core.config import LOGGER_NAME
from os_ai_core.tools.registry import ToolRegistry
from os_ai_core.tools.computer import computer_tool_handler_batch


class LLMModule(injector.Module):
    def __init__(
        self,
        provider: Optional[str] = None,
        api_key: Optional[str] = None,
        provider_options: Optional[dict[str, str]] = None,
    ) -> None:
        self._provider = (provider or LLM_PROVIDER).lower()
        self._api_key = api_key
        self._provider_options = provider_options or {}

    @injector.provider
    def provide_llm_client(self) -> LLMClient:  # type: ignore[override]
        if self._provider == "openai":
            from os_ai_llm_openai.adapters_openai import OpenAIClient
            return OpenAIClient(api_key=self._api_key)
        elif self._provider == "azure_openai":
            from os_ai_llm_openai.adapters_openai import AzureOpenAIClient
            return AzureOpenAIClient(
                api_key=self._api_key,
                model_name=self._provider_options.get("deployment"),
                azure_endpoint=self._provider_options.get("endpoint"),
                api_version=self._provider_options.get("api_version"),
            )
        elif self._provider == "anthropic":
            from os_ai_llm_anthropic.adapters_anthropic import AnthropicClient
            return AnthropicClient(api_key=self._api_key)
        else:
            raise ValueError(f"Unknown LLM provider: '{self._provider}'. Supported: 'anthropic', 'openai', 'azure_openai'")


class ToolsModule(injector.Module):
    def __init__(self, provider: Optional[str] = None) -> None:
        self._provider = (provider or LLM_PROVIDER).lower()

    @injector.singleton
    @injector.provider
    def provide_tool_registry(self) -> ToolRegistry:  # type: ignore[override]
        reg = ToolRegistry()
        reg.register("computer", computer_tool_handler_batch)
        return reg

    @injector.singleton
    @injector.provider
    def provide_tool_gateway(self, tool_registry: ToolRegistry) -> CompositeToolGateway:  # type: ignore[override]
        strict_metadata = os.environ.get("OS_AI_STRICT_PROVIDER_METADATA", "1").lower() not in {"0", "false", "no", "off"}
        providers = [
            LocalComputerToolProvider(
                tool_registry,
                descriptors=[build_computer_tool_descriptor(self._provider)],
                strict_provider_metadata=strict_metadata,
            )
        ]
        try:
            from os_ai_mcp.client.factory import create_mcp_tool_providers_from_env

            providers.extend(create_mcp_tool_providers_from_env())
        except Exception as exc:
            if os.environ.get("OS_AI_MCP_ENABLED", "0").lower() in {"1", "true", "yes", "on"}:
                logging.getLogger(LOGGER_NAME).warning("MCP providers are disabled: %s", exc)
        return CompositeToolGateway(providers)


def create_container(
    provider: Optional[str] = None,
    api_key: Optional[str] = None,
    provider_options: Optional[dict[str, str]] = None,
) -> injector.Injector:
    return injector.Injector([LLMModule(provider, api_key=api_key, provider_options=provider_options), ToolsModule(provider)])
