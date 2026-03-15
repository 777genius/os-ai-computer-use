import importlib.util
import sys
from pathlib import Path

import pytest

_IS_MAC = sys.platform == "darwin"
_META = "command" if _IS_MAC else "win"
_ALT = "option" if _IS_MAC else "alt"


def _load_main():
    proj_root = Path(__file__).resolve().parents[2]
    main_path = proj_root / "main.py"
    if str(proj_root) not in sys.path:
        sys.path.insert(0, str(proj_root))
    spec = importlib.util.spec_from_file_location("agent_core_main", str(main_path))
    assert spec and spec.loader, "Failed to load main.py"
    main = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(main)  # type: ignore
    return main


@pytest.mark.parametrize(
    "mods_str,expected",
    [
        ("shift", ["shift"]),
        ("cmd+shift", [_META, "shift"]),
        ("ctrl+alt", ["ctrl", _ALT]),
    ],
)
def test_click_with_modifiers(monkeypatch, mods_str, expected):
    main = _load_main()

    calls = {"keyDown": [], "keyUp": [], "click": [], "moveTo": []}

    monkeypatch.setattr(main.pyautogui, "keyDown", lambda k: calls["keyDown"].append(k))
    monkeypatch.setattr(main.pyautogui, "keyUp", lambda k: calls["keyUp"].append(k))
    monkeypatch.setattr(main.pyautogui, "click", lambda **kw: calls["click"].append(kw))
    monkeypatch.setattr(main.pyautogui, "moveTo", lambda x, y, **kw: calls["moveTo"].append((x, y)))

    main.handle_computer_action("left_click", {"coordinate": [10, 20], "modifiers": mods_str})

    assert calls["moveTo"], "expected moveTo before click"
    # modifiers pressed in order
    assert calls["keyDown"] == expected
    # released in reverse
    assert calls["keyUp"] == list(reversed(expected))
    assert calls["click"], "expected click call"


def test_drag_with_tuning_and_modifiers(monkeypatch):
    main = _load_main()

    order = []

    def moveTo(x, y, **kw):
        order.append(("move", x, y))

    def mouseDown(**kw):
        order.append(("down", kw.get("button")))

    def mouseUp(**kw):
        order.append(("up", kw.get("button")))

    def keyDown(k):
        order.append(("kd", k))

    def keyUp(k):
        order.append(("ku", k))

    monkeypatch.setattr(main.pyautogui, "moveTo", moveTo)
    monkeypatch.setattr(main.pyautogui, "mouseDown", mouseDown)
    monkeypatch.setattr(main.pyautogui, "mouseUp", mouseUp)
    monkeypatch.setattr(main.pyautogui, "keyDown", keyDown)
    monkeypatch.setattr(main.pyautogui, "keyUp", keyUp)

    main.handle_computer_action(
        "left_click_drag",
        {
            "start": [0, 0],
            "end": [10, 0],
            "hold_before_ms": 10,
            "hold_after_ms": 10,
            "steps": 3,
            "step_delay": 0.0,
            "modifiers": "shift",
        },
    )

    # Expect: move(start) -> kd(shift) -> down -> move(step1) -> move(step2) -> move(end) -> up -> ku(shift)
    assert order[0][0] == "move" and order[0][1:] == (0, 0)
    assert ("kd", "shift") in order
    assert ("down", "left") in order
    assert ("up", "left") in order
    assert order[-1] == ("ku", "shift")


