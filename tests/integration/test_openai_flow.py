"""Integration tests for OpenAI adapter flow with mocked SDK."""

from __future__ import annotations

from unittest.mock import MagicMock, patch, call
from typing import Any, Dict, List
import pytest

from os_ai_llm.types import (
    Message, TextPart, ImagePart, ToolDescriptor, ToolCall, ToolResult, ProviderPart, LLMResponse, Usage,
)
from os_ai_llm_openai.adapters_openai import OpenAIClient


def _make_mock_response(response_id: str, output_items: list, input_tokens: int = 10, output_tokens: int = 5):
    """Build a mock OpenAI Responses API response."""
    resp = MagicMock()
    resp.id = response_id
    resp.output = output_items

    usage = MagicMock()
    usage.input_tokens = input_tokens
    usage.output_tokens = output_tokens
    usage.total_tokens = input_tokens + output_tokens
    resp.usage = usage
    return resp


def _make_computer_call(call_id: str, actions: list, safety_checks=None):
    """Build a mock ResponseComputerToolCall."""
    item = MagicMock()
    item.type = "computer_call"
    item.call_id = call_id
    item.id = f"cu_{call_id}"
    item.actions = actions
    item.pending_safety_checks = safety_checks
    item.action = None  # GA tool uses actions, not action
    return item


def _make_action(action_type: str, **kwargs):
    """Build a mock SDK action object."""
    act = MagicMock()
    act.type = action_type
    for k, v in kwargs.items():
        setattr(act, k, v)
    # Ensure missing attrs return None via getattr
    for field in ("x", "y", "button", "text", "keys", "scroll_x", "scroll_y", "path"):
        if field not in kwargs:
            setattr(act, field, None)
    return act


def _make_message(text: str):
    """Build a mock ResponseOutputMessage."""
    item = MagicMock()
    item.type = "message"
    content_block = MagicMock()
    content_block.type = "output_text"
    content_block.text = text
    item.content = [content_block]
    return item


@pytest.fixture
def client():
    with patch.dict("os.environ", {"OPENAI_API_KEY": "test-key"}):
        with patch("os_ai_llm_openai.adapters_openai.OpenAI") as MockOpenAI:
            c = OpenAIClient(api_key="test-key")
            c._mock_openai = MockOpenAI.return_value
            yield c


def test_provider_context_roundtrip(client):
    """previous_response_id flows from response to next request."""
    # First call: no provider_context
    resp1 = _make_mock_response("resp_1", [
        _make_computer_call("call_1", [_make_action("screenshot")]),
    ])
    client._mock_openai.responses.create.return_value = resp1

    result1 = client.generate(
        messages=[Message(role="user", content=[TextPart(text="test")])],
        tools=[ToolDescriptor(name="computer", kind="computer_use")],
        system="You are helpful.",
        provider_context=None,
    )

    assert result1.provider_context == {"previous_response_id": "resp_1"}

    # Second call: with provider_context
    resp2 = _make_mock_response("resp_2", [_make_message("Done!")])
    client._mock_openai.responses.create.return_value = resp2

    # Build tool result message
    tool_result_msg = client.format_tool_result(ToolResult(
        tool_call_id="call_1",
        content=[ImagePart(data_base64="screenshot_data", media_type="image/png")],
    ))

    result2 = client.generate(
        messages=[
            Message(role="user", content=[TextPart(text="test")]),
            Message(role="assistant", content=[TextPart(text="")]),
            tool_result_msg,
        ],
        tools=[ToolDescriptor(name="computer", kind="computer_use")],
        system="You are helpful.",
        provider_context={"previous_response_id": "resp_1"},
    )

    assert result2.provider_context == {"previous_response_id": "resp_2"}

    # Verify previous_response_id was sent
    second_call_kwargs = client._mock_openai.responses.create.call_args_list[1]
    assert second_call_kwargs.kwargs.get("previous_response_id") == "resp_1"
    # Verify instructions re-sent
    assert second_call_kwargs.kwargs.get("instructions") == "You are helpful."


def test_safety_checks_roundtrip(client):
    """pending_safety_checks are propagated to acknowledged_safety_checks."""
    safety = [MagicMock(id="sc_1", code="sensitive_domain", message="Banking site detected")]
    resp = _make_mock_response("resp_1", [
        _make_computer_call("call_1", [_make_action("screenshot")], safety_checks=safety),
    ])
    client._mock_openai.responses.create.return_value = resp

    result = client.generate(
        messages=[Message(role="user", content=[TextPart(text="test")])],
        tools=[ToolDescriptor(name="computer", kind="computer_use")],
    )

    # Safety checks should be in ToolCall metadata
    assert len(result.tool_calls) == 1
    tc = result.tool_calls[0]
    checks = tc.metadata.get("_openai_pending_safety_checks", [])
    assert len(checks) == 1
    assert checks[0]["id"] == "sc_1"
    assert checks[0]["code"] == "sensitive_domain"

    # Format tool result with safety checks in metadata
    tr = ToolResult(
        tool_call_id="call_1",
        content=[ImagePart(data_base64="img", media_type="image/png")],
        metadata={"_openai_pending_safety_checks": checks},
    )
    msg = client.format_tool_result(tr)

    # Verify acknowledged_safety_checks in output
    pp = msg.content[0]
    assert isinstance(pp, ProviderPart)
    output_data = pp.data
    acks = output_data.get("acknowledged_safety_checks", [])
    assert len(acks) == 1
    assert acks[0]["id"] == "sc_1"
    assert acks[0]["code"] == "sensitive_domain"


def test_batch_actions_parsed(client):
    """Multiple actions in one computer_call are parsed correctly."""
    resp = _make_mock_response("resp_1", [
        _make_computer_call("call_1", [
            _make_action("click", x=100, y=200, button="left"),
            _make_action("type", text="hello"),
            _make_action("keypress", keys=["Enter"]),
        ]),
    ])
    client._mock_openai.responses.create.return_value = resp

    result = client.generate(
        messages=[Message(role="user", content=[TextPart(text="test")])],
        tools=[ToolDescriptor(name="computer", kind="computer_use")],
    )

    assert len(result.tool_calls) == 1
    tc = result.tool_calls[0]
    assert tc.args["action"] == "left_click"  # first action in args
    actions = tc.metadata["_openai_actions"]
    assert len(actions) == 3
    assert actions[0]["action"] == "left_click"
    assert actions[1]["action"] == "type"
    assert actions[2]["action"] == "key"


def test_empty_actions_list(client):
    """computer_call with empty actions produces fallback screenshot action."""
    resp = _make_mock_response("resp_1", [
        _make_computer_call("call_1", []),
    ])
    client._mock_openai.responses.create.return_value = resp

    result = client.generate(
        messages=[Message(role="user", content=[TextPart(text="test")])],
        tools=[ToolDescriptor(name="computer", kind="computer_use")],
    )

    assert len(result.tool_calls) == 1
    assert result.tool_calls[0].args == {"action": "screenshot"}


def test_multiple_computer_calls(client):
    """Two computer_calls in one response produce two ToolCalls."""
    resp = _make_mock_response("resp_1", [
        _make_computer_call("call_A", [_make_action("click", x=10, y=20, button="left")]),
        _make_computer_call("call_B", [_make_action("type", text="hi")]),
    ])
    client._mock_openai.responses.create.return_value = resp

    result = client.generate(
        messages=[Message(role="user", content=[TextPart(text="test")])],
        tools=[ToolDescriptor(name="computer", kind="computer_use")],
    )

    assert len(result.tool_calls) == 2
    assert result.tool_calls[0].id == "call_A"
    assert result.tool_calls[1].id == "call_B"


def test_text_and_computer_call_together(client):
    """Response with both message and computer_call captures both."""
    resp = _make_mock_response("resp_1", [
        _make_message("I'll click there"),
        _make_computer_call("call_1", [_make_action("click", x=50, y=60, button="left")]),
    ])
    client._mock_openai.responses.create.return_value = resp

    result = client.generate(
        messages=[Message(role="user", content=[TextPart(text="test")])],
        tools=[ToolDescriptor(name="computer", kind="computer_use")],
    )

    # Text in messages
    assert any(
        isinstance(p, TextPart) and "click" in p.text.lower()
        for m in result.messages for p in m.content
    )
    # Tool call present
    assert len(result.tool_calls) == 1


def test_error_response_on_rate_limit(client):
    """RateLimitError returns error LLMResponse instead of raising."""
    from openai import RateLimitError
    err_resp = MagicMock()
    err_resp.status_code = 429
    err_resp.json.return_value = {"error": {"message": "rate limited"}}
    client._mock_openai.responses.create.side_effect = RateLimitError(
        message="rate limited", response=err_resp, body=None,
    )

    result = client.generate(
        messages=[Message(role="user", content=[TextPart(text="test")])],
        tools=[ToolDescriptor(name="computer", kind="computer_use")],
    )

    assert len(result.tool_calls) == 0
    assert any("rate limited" in p.text.lower() for m in result.messages for p in m.content if isinstance(p, TextPart))
