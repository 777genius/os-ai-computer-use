from __future__ import annotations

from os_ai_llm_anthropic.adapters_anthropic import AnthropicClient
from os_ai_llm.types import Message, TextPart, ImagePart, ToolDescriptor, ToolResult, ProviderPart
import os
import pytest


class DummyAnthropic:
    class Beta:
        class Messages:
            def create(self, **kwargs):
                msgs = kwargs.get("messages", [])
                assert isinstance(msgs, list) and msgs, "messages should not be empty"
                first = msgs[0]
                assert first.get("role") == "user"
                assert first.get("content"), "first message content must be non-empty"

                class Resp:
                    def __init__(self):
                        self.content = []
                        class Usage:
                            input_tokens = 1
                            output_tokens = 1
                        self.usage = Usage()
                return Resp()
        def __init__(self):
            self.messages = DummyAnthropic.Beta.Messages()
    def __init__(self, **kwargs):
        self.beta = DummyAnthropic.Beta()


def _make_client(monkeypatch):
    monkeypatch.setenv("ANTHROPIC_API_KEY", "x")
    import os_ai_llm_anthropic.adapters_anthropic as aa
    aa.anthropic.Anthropic = DummyAnthropic  # type: ignore
    return AnthropicClient()


def test_anthropic_adapter_builds_valid_messages(monkeypatch):
    client = _make_client(monkeypatch)
    resp = client.generate(
        messages=[Message(role="user", content=[TextPart(text="hi")])],
        tools=[ToolDescriptor(name="computer", kind="computer_use", params={"display_width_px": 10, "display_height_px": 10})],
        system=None,
        max_tokens=50,
    )
    assert resp.usage.input_tokens == 1


def test_format_tool_result_returns_provider_part(monkeypatch):
    """format_tool_result() returns Message with ProviderPart, not TextPart marker."""
    client = _make_client(monkeypatch)
    result = ToolResult(
        tool_call_id="test_id",
        content=[TextPart(text="ok"), ImagePart(media_type="image/png", data_base64="abc")],
    )
    msg = client.format_tool_result(result)
    assert msg.role == "user"
    assert len(msg.content) == 1
    part = msg.content[0]
    assert isinstance(part, ProviderPart)
    assert part.provider == "anthropic"
    assert part.sub_type == "tool_result"
    assert isinstance(part.data, list)
    # Verify native block structure
    block = part.data[0]
    assert block["type"] == "tool_result"
    assert block["tool_use_id"] == "test_id"
    assert len(block["content"]) == 2  # text + image


def test_to_provider_messages_expands_provider_part(monkeypatch):
    """_to_provider_messages() correctly expands ProviderPart back to native blocks."""
    client = _make_client(monkeypatch)
    tool_use_blocks = [{"type": "tool_use", "id": "tu_1", "name": "computer", "input": {"action": "screenshot"}}]
    msg = Message(role="assistant", content=[
        TextPart(text="thinking..."),
        ProviderPart(provider="anthropic", sub_type="tool_use", data=tool_use_blocks),
    ])
    provider_msgs = client._to_provider_messages([msg])
    assert len(provider_msgs) == 1
    blocks = provider_msgs[0]["content"]
    # Should have text block + expanded tool_use block
    assert any(b.get("type") == "text" for b in blocks)
    assert any(b.get("type") == "tool_use" and b.get("id") == "tu_1" for b in blocks)


def test_to_provider_messages_skips_other_provider_parts(monkeypatch):
    """ProviderPart from other providers is silently skipped."""
    client = _make_client(monkeypatch)
    msg = Message(role="user", content=[
        TextPart(text="hello"),
        ProviderPart(provider="openai", sub_type="computer_call_output", data={"some": "data"}),
    ])
    provider_msgs = client._to_provider_messages([msg])
    blocks = provider_msgs[0]["content"]
    # Only text block, openai ProviderPart skipped
    assert len(blocks) == 1
    assert blocks[0]["type"] == "text"
