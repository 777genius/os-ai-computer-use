import importlib.util
import sys
from pathlib import Path


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


def test_key_cmd_space_hotkey(monkeypatch):
    main = _load_main()

    calls = {
        "hotkey": [],
        "press": [],
    }

    def hotkey(*keys):
        calls["hotkey"].append(tuple(keys))

    def press(key):
        calls["press"].append(key)

    monkeypatch.setattr(main.pyautogui, "hotkey", hotkey)
    monkeypatch.setattr(main.pyautogui, "press", press)

    res = main.handle_computer_action("key", {"key": "cmd+space"})

    assert calls["hotkey"] == [("command", "space")]
    assert calls["press"] == []
    assert any("pressed" in c.get("text", "") for c in res)


def test_hold_key_cmd_k_order(monkeypatch):
    main = _load_main()

    order = []

    def keyDown(k):
        order.append(("down", k))

    def keyUp(k):
        order.append(("up", k))

    def press(k):
        order.append(("press", k))

    monkeypatch.setattr(main.pyautogui, "keyDown", keyDown)
    monkeypatch.setattr(main.pyautogui, "keyUp", keyUp)
    monkeypatch.setattr(main.pyautogui, "press", press)

    main.handle_computer_action("hold_key", {"key": "cmd+k"})

    # Expect: command down -> press 'k' -> command up
    assert order == [("down", "command"), ("press", "k"), ("up", "command")]


def test_enter_uses_press_enter_mac(monkeypatch):
    main = _load_main()

    flags = {"enter": 0, "press": []}

    def press_enter_mac():
        flags["enter"] += 1

    def press(k):
        flags["press"].append(k)

    monkeypatch.setattr(main, "press_enter_mac", press_enter_mac)
    monkeypatch.setattr(main.pyautogui, "press", press)

    main.handle_computer_action("key", {"key": "enter"})

    assert flags["enter"] == 1
    # Fallback pyautogui.press("enter") не должен вызываться в штатном сценарии
    assert flags["press"] == []


def test_text_Return_maps_to_enter_press(monkeypatch):
    main = _load_main()

    flags = {"enter": 0, "press": []}

    def press_enter_mac():
        flags["enter"] += 1

    def press(k):
        flags["press"].append(k)

    monkeypatch.setattr(main, "press_enter_mac", press_enter_mac)
    monkeypatch.setattr(main.pyautogui, "press", press)

    res = main.handle_computer_action("key", {"text": "Return"})

    # One enter press via Quartz helper
    assert flags["enter"] == 1
    assert flags["press"] == []
    assert any("pressed" in c.get("text", "") for c in res)


def test_text_Return_Return_twice(monkeypatch):
    main = _load_main()

    calls = {"enter": 0, "press": []}

    def press_enter_mac():
        calls["enter"] += 1

    def press(k):
        calls["press"].append(k)

    monkeypatch.setattr(main, "press_enter_mac", press_enter_mac)
    monkeypatch.setattr(main.pyautogui, "press", press)

    res = main.handle_computer_action("key", {"text": "Return Return"})

    # Should press enter twice, not type literal text
    assert calls["enter"] == 2
    assert calls["press"] == []
    assert any("pressed" in c.get("text", "") for c in res)


def test_type_singleline_uses_write_not_paste(monkeypatch):
    main = _load_main()

    calls = {"write": [], "hotkey": []}

    def write(text, interval=0.0):
        calls["write"].append(text)

    def hotkey(*keys):
        calls["hotkey"].append(tuple(keys))

    monkeypatch.setattr(main.pyautogui, "write", write)
    monkeypatch.setattr(main.pyautogui, "hotkey", hotkey)

    res = main.handle_computer_action("type", {"text": "hello world"})

    assert calls["write"] == ["hello world"]
    assert calls["hotkey"] == []
    assert any("done: type" in c.get("text", "") for c in res)

