"""Tests for computer_tool_handler_batch."""

from __future__ import annotations

from unittest.mock import patch, MagicMock
import pytest


@pytest.fixture(autouse=True)
def _mock_pyautogui(monkeypatch):
    """Prevent real mouse/keyboard actions during tests."""
    mock_pag = MagicMock()
    mock_pag.size.return_value = (1920, 1080)
    mock_pag.position.return_value = (0, 0)
    mock_pag.FAILSAFE = False
    mock_pag.PAUSE = 0
    monkeypatch.setattr("os_ai_core.tools.computer.pyautogui", mock_pag)
    return mock_pag


def test_single_action_delegates(monkeypatch):
    """Without _openai_batch flag, delegates to computer_tool_handler."""
    from os_ai_core.tools.computer import computer_tool_handler_batch

    with patch("os_ai_core.tools.computer.computer_tool_handler") as mock_handler:
        mock_handler.return_value = [{"type": "text", "text": "ok"}]
        result = computer_tool_handler_batch({"action": "screenshot"})
        mock_handler.assert_called_once_with({"action": "screenshot"})
        assert result == [{"type": "text", "text": "ok"}]


def test_batch_empty_actions(monkeypatch):
    """Batch with empty actions list returns screenshot."""
    from os_ai_core.tools.computer import computer_tool_handler_batch

    with patch("os_ai_core.tools.computer.b64_image_from_screenshot") as mock_ss:
        mock_ss.return_value = {"type": "image", "source": {"type": "base64", "media_type": "image/png", "data": "abc"}}
        result = computer_tool_handler_batch({"_openai_batch": True, "_openai_actions": []})
        mock_ss.assert_called_once()
        assert result[0]["type"] == "image"


def test_batch_three_actions(monkeypatch):
    """Batch executes all actions and returns single screenshot."""
    from os_ai_core.tools.computer import computer_tool_handler_batch

    call_log = []

    def fake_handle(action, params):
        call_log.append(action)
        return [{"type": "text", "text": f"done: {action}"}]

    with patch("os_ai_core.tools.computer.handle_computer_action", side_effect=fake_handle):
        with patch("os_ai_core.tools.computer.b64_image_from_screenshot") as mock_ss:
            mock_ss.return_value = {"type": "image", "source": {"type": "base64", "media_type": "image/png", "data": "xyz"}}
            result = computer_tool_handler_batch({
                "_openai_batch": True,
                "_openai_actions": [
                    {"action": "left_click", "coordinate": [100, 200]},
                    {"action": "type", "text": "hello"},
                    {"action": "key", "key": "enter"},
                ],
            })

    assert call_log == ["left_click", "type", "key"]
    assert len(result) == 1
    assert result[0]["type"] == "image"


def test_batch_skips_screenshot_actions(monkeypatch):
    """Screenshot actions inside batch are skipped."""
    from os_ai_core.tools.computer import computer_tool_handler_batch

    call_log = []

    def fake_handle(action, params):
        call_log.append(action)
        return [{"type": "text", "text": "ok"}]

    with patch("os_ai_core.tools.computer.handle_computer_action", side_effect=fake_handle):
        with patch("os_ai_core.tools.computer.b64_image_from_screenshot") as mock_ss:
            mock_ss.return_value = {"type": "image", "source": {"type": "base64", "media_type": "image/png", "data": ""}}
            computer_tool_handler_batch({
                "_openai_batch": True,
                "_openai_actions": [
                    {"action": "screenshot"},
                    {"action": "left_click", "coordinate": [10, 20]},
                    {"action": "screenshot"},
                ],
            })

    assert call_log == ["left_click"]  # screenshots skipped


def test_batch_continues_on_error(monkeypatch):
    """If one action fails, batch continues with remaining actions."""
    from os_ai_core.tools.computer import computer_tool_handler_batch

    call_count = [0]

    def fake_handle(action, params):
        call_count[0] += 1
        if call_count[0] == 2:
            raise RuntimeError("simulated failure")
        return [{"type": "text", "text": "ok"}]

    with patch("os_ai_core.tools.computer.handle_computer_action", side_effect=fake_handle):
        with patch("os_ai_core.tools.computer.b64_image_from_screenshot") as mock_ss:
            mock_ss.return_value = {"type": "image", "source": {"type": "base64", "media_type": "image/png", "data": ""}}
            result = computer_tool_handler_batch({
                "_openai_batch": True,
                "_openai_actions": [
                    {"action": "left_click", "coordinate": [1, 1]},
                    {"action": "type", "text": "fail here"},
                    {"action": "key", "key": "enter"},
                ],
            })

    assert call_count[0] == 3  # all three attempted
    assert result[0]["type"] == "image"  # screenshot returned
