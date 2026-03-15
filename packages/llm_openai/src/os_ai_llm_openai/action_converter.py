"""Convert between OpenAI computer_call actions and internal action format.

OpenAI format:  {"type": "click", "x": 405, "y": 157, "button": "left"}
Internal format: {"action": "left_click", "coordinate": [405, 157]}

Internal format is what computer_tool_handler() in core/tools/computer.py expects.
"""

from __future__ import annotations

import logging
from typing import Any, Dict, List

from os_ai_llm_openai.config import SCROLL_PIXELS_PER_CLICK

_LOGGER = logging.getLogger("os_ai")

# OpenAI key names -> internal (xdotool-style) key names
_OPENAI_KEY_MAP = {
    "Control": "ctrl",
    "Shift": "shift",
    "Alt": "alt",
    "Meta": "command",
    "Enter": "enter",
    "Return": "enter",
    "Escape": "esc",
    "Backspace": "backspace",
    "Delete": "delete",
    "Tab": "tab",
    "Space": "space",
    "ArrowUp": "up",
    "ArrowDown": "down",
    "ArrowLeft": "left",
    "ArrowRight": "right",
    "Home": "home",
    "End": "end",
    "PageUp": "pageup",
    "PageDown": "pagedown",
    "CapsLock": "capslock",
    "Insert": "insert",
    "PrintScreen": "printscreen",
}


def _extract_coord(pt: Any, field: str) -> int:
    """Extract coordinate from SDK Pydantic object or dict."""
    if isinstance(pt, dict):
        return int(pt.get(field, 0))
    return int(getattr(pt, field, 0))


def openai_keys_to_xdotool(keys: List[str]) -> str:
    """Convert OpenAI keys array ["Control", "s"] to xdotool combo "ctrl+s"."""
    result = []
    for key in keys:
        mapped = _OPENAI_KEY_MAP.get(key)
        if mapped:
            result.append(mapped)
        elif key.startswith("F") and key[1:].isdigit() and 1 <= int(key[1:]) <= 24:
            result.append(key.lower())
        elif len(key) == 1:
            result.append(key.lower())
        else:
            result.append(key.lower())
    return "+".join(result)


def openai_scroll_to_internal(scroll_x: int, scroll_y: int) -> Dict[str, Any]:
    """Convert OpenAI pixel-based scroll to internal direction+amount format."""
    ppc = SCROLL_PIXELS_PER_CLICK
    if scroll_x == 0 and scroll_y == 0:
        return {"scroll_direction": "down", "scroll_amount": 0}
    if abs(scroll_y) >= abs(scroll_x):
        # OpenAI convention: positive scroll_y = DOWN, negative = UP
        direction = "down" if scroll_y > 0 else "up"
        amount = max(1, abs(scroll_y) // ppc)
        return {"scroll_direction": direction, "scroll_amount": amount}
    else:
        direction = "right" if scroll_x > 0 else "left"
        amount = max(1, abs(scroll_x) // ppc)
        return {"scroll_direction": direction, "scroll_amount": amount}


def openai_action_to_internal(action: Dict[str, Any]) -> Dict[str, Any]:
    """Convert a single OpenAI action to internal format."""
    action_type = action.get("type", "")

    if action_type == "screenshot":
        return {"action": "screenshot"}

    if action_type == "click":
        button = action.get("button", "left")
        x, y = int(action.get("x", 0)), int(action.get("y", 0))
        if button in ("back", "forward"):
            _LOGGER.warning("Mouse button '%s' not supported by pyautogui, skipping click", button)
            return {"action": "screenshot"}
        action_name = {
            "left": "left_click",
            "right": "right_click",
            "middle": "middle_click",
            "wheel": "middle_click",
        }.get(button, "left_click")
        return {"action": action_name, "coordinate": [x, y]}

    if action_type == "double_click":
        x, y = int(action.get("x", 0)), int(action.get("y", 0))
        return {"action": "double_click", "coordinate": [x, y]}

    if action_type == "type":
        return {"action": "type", "text": action.get("text", "")}

    if action_type == "keypress":
        keys = action.get("keys", [])
        combo = openai_keys_to_xdotool(keys) if keys else ""
        return {"action": "key", "key": combo}

    if action_type == "scroll":
        x, y = int(action.get("x", 0)), int(action.get("y", 0))
        scroll_x = int(action.get("scroll_x", 0))
        scroll_y = int(action.get("scroll_y", 0))
        result: Dict[str, Any] = {"action": "scroll", "coordinate": [x, y]}
        result.update(openai_scroll_to_internal(scroll_x, scroll_y))
        return result

    if action_type == "move":
        x, y = int(action.get("x", 0)), int(action.get("y", 0))
        return {"action": "mouse_move", "coordinate": [x, y]}

    if action_type == "drag":
        path = action.get("path", [])
        if len(path) >= 2:
            start = path[0]
            end = path[-1]
            # Pass full path as intermediate points for smooth drawing
            full_path = [
                [_extract_coord(pt, "x"), _extract_coord(pt, "y")]
                for pt in path
            ]
            return {
                "action": "left_click_drag",
                "start_coordinate": [_extract_coord(start, "x"), _extract_coord(start, "y")],
                "end_coordinate": [_extract_coord(end, "x"), _extract_coord(end, "y")],
                "path": full_path,
            }
        _LOGGER.warning("Drag with path < 2 points, fallback to screenshot")
        return {"action": "screenshot"}

    if action_type == "wait":
        return {"action": "wait", "seconds": 2.0}

    _LOGGER.warning("Unknown OpenAI action type '%s', fallback to screenshot", action_type)
    return {"action": "screenshot"}


def openai_actions_to_internal(actions: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Convert list of OpenAI actions to list of internal actions."""
    return [openai_action_to_internal(a) for a in actions]
