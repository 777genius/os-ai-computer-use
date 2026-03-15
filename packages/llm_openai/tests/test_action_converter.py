"""Tests for OpenAI action → internal format conversion."""

from __future__ import annotations

import sys
import os

# Add package source paths for direct test execution
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "llm", "src"))

from os_ai_llm_openai.action_converter import (
    openai_action_to_internal,
    openai_actions_to_internal,
    openai_keys_to_xdotool,
    openai_scroll_to_internal,
)


# === Click ===

def test_left_click():
    r = openai_action_to_internal({"type": "click", "x": 100, "y": 200, "button": "left"})
    assert r == {"action": "left_click", "coordinate": [100, 200]}


def test_right_click():
    r = openai_action_to_internal({"type": "click", "x": 50, "y": 75, "button": "right"})
    assert r == {"action": "right_click", "coordinate": [50, 75]}


def test_middle_click():
    r = openai_action_to_internal({"type": "click", "x": 0, "y": 0, "button": "middle"})
    assert r == {"action": "middle_click", "coordinate": [0, 0]}


def test_click_default_button():
    r = openai_action_to_internal({"type": "click", "x": 100, "y": 200})
    assert r == {"action": "left_click", "coordinate": [100, 200]}


def test_double_click():
    r = openai_action_to_internal({"type": "double_click", "x": 300, "y": 400})
    assert r == {"action": "double_click", "coordinate": [300, 400]}


# === Type ===

def test_type_text():
    r = openai_action_to_internal({"type": "type", "text": "hello world"})
    assert r == {"action": "type", "text": "hello world"}


def test_type_empty():
    r = openai_action_to_internal({"type": "type"})
    assert r == {"action": "type", "text": ""}


# === Keypress ===

def test_keypress_single():
    assert openai_keys_to_xdotool(["Enter"]) == "enter"


def test_keypress_combo():
    assert openai_keys_to_xdotool(["Control", "s"]) == "ctrl+s"


def test_keypress_complex():
    assert openai_keys_to_xdotool(["Control", "Shift", "p"]) == "ctrl+shift+p"


def test_keypress_arrows():
    assert openai_keys_to_xdotool(["ArrowDown"]) == "down"
    assert openai_keys_to_xdotool(["ArrowUp"]) == "up"
    assert openai_keys_to_xdotool(["ArrowLeft"]) == "left"
    assert openai_keys_to_xdotool(["ArrowRight"]) == "right"


def test_keypress_fkeys():
    assert openai_keys_to_xdotool(["F5"]) == "f5"
    assert openai_keys_to_xdotool(["F12"]) == "f12"


def test_keypress_meta():
    assert openai_keys_to_xdotool(["Meta", "c"]) == "command+c"


def test_keypress_action():
    r = openai_action_to_internal({"type": "keypress", "keys": ["Control", "a"]})
    assert r == {"action": "key", "key": "ctrl+a"}


def test_keypress_empty_keys():
    r = openai_action_to_internal({"type": "keypress", "keys": []})
    assert r == {"action": "key", "key": ""}


# === Scroll ===

def test_scroll_down():
    # OpenAI: positive scroll_y = DOWN
    r = openai_scroll_to_internal(0, 300)
    assert r["scroll_direction"] == "down"
    assert r["scroll_amount"] == 3


def test_scroll_up():
    # OpenAI: negative scroll_y = UP
    r = openai_scroll_to_internal(0, -200)
    assert r["scroll_direction"] == "up"
    assert r["scroll_amount"] == 2


def test_scroll_right():
    r = openai_scroll_to_internal(500, 0)
    assert r["scroll_direction"] == "right"
    assert r["scroll_amount"] == 5


def test_scroll_zero():
    r = openai_scroll_to_internal(0, 0)
    assert r["scroll_amount"] == 0


def test_scroll_minimum():
    r = openai_scroll_to_internal(0, 10)
    assert r["scroll_amount"] == 1


def test_scroll_action():
    r = openai_action_to_internal({
        "type": "scroll", "x": 500, "y": 300, "scroll_x": 0, "scroll_y": 300,
    })
    assert r["action"] == "scroll"
    assert r["coordinate"] == [500, 300]
    assert r["scroll_direction"] == "down"
    assert r["scroll_amount"] == 3


# === Move ===

def test_move():
    r = openai_action_to_internal({"type": "move", "x": 100, "y": 200})
    assert r == {"action": "mouse_move", "coordinate": [100, 200]}


# === Drag ===

def test_drag_two_points():
    r = openai_action_to_internal({
        "type": "drag",
        "path": [{"x": 100, "y": 200}, {"x": 300, "y": 400}],
    })
    assert r["action"] == "left_click_drag"
    assert r["start_coordinate"] == [100, 200]
    assert r["end_coordinate"] == [300, 400]
    assert r["path"] == [[100, 200], [300, 400]]


def test_drag_three_points():
    r = openai_action_to_internal({
        "type": "drag",
        "path": [{"x": 0, "y": 0}, {"x": 50, "y": 50}, {"x": 100, "y": 100}],
    })
    assert r["start_coordinate"] == [0, 0]
    assert r["end_coordinate"] == [100, 100]


def test_drag_one_point():
    r = openai_action_to_internal({"type": "drag", "path": [{"x": 0, "y": 0}]})
    assert r == {"action": "screenshot"}


# === Special actions ===

def test_screenshot():
    r = openai_action_to_internal({"type": "screenshot"})
    assert r == {"action": "screenshot"}


def test_wait_default():
    r = openai_action_to_internal({"type": "wait"})
    assert r == {"action": "wait", "seconds": 2.0}


def test_unknown_action():
    r = openai_action_to_internal({"type": "something_new"})
    assert r == {"action": "screenshot"}


# === Batch converter ===

def test_batch_converter():
    actions = [
        {"type": "click", "x": 10, "y": 20, "button": "left"},
        {"type": "type", "text": "hi"},
    ]
    results = openai_actions_to_internal(actions)
    assert len(results) == 2
    assert results[0]["action"] == "left_click"
    assert results[1]["action"] == "type"
