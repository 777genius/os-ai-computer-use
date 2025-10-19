import importlib
import importlib.util
import sys
import types


def _install_quartz_mock(monkeypatch):
    calls = {"events": []}
    module = types.ModuleType("Quartz")

    def CGEventCreateKeyboardEvent(src, keycode, keyDown):
        calls["events"].append(("create", keycode, bool(keyDown)))
        return object()

    def CGEventPost(tap, event):
        calls["events"].append(("post", tap, event))

    module.CGEventCreateKeyboardEvent = CGEventCreateKeyboardEvent
    module.CGEventPost = CGEventPost
    module.kCGHIDEventTap = 0
    monkeypatch.setitem(sys.modules, "Quartz", module)
    return calls


def test_press_enter_mac_success(monkeypatch):
    calls = _install_quartz_mock(monkeypatch)
    # re-import keyboard with mocked Quartz
    keyboard = importlib.import_module("os_ai_os_macos.keyboard")

    keyboard.press_enter_mac()

    # Expect: create keyDown, post, then keyUp, post
    assert ("create", 36, True) in calls["events"] or ("create", 36, 1) in calls["events"]
    assert any(e[0] == "post" for e in calls["events"])  # at least one post


def test_press_keycode_safe_on_exception(monkeypatch):
    # Quartz поднимет исключение — функция не должна падать
    def raise_exc(*args, **kwargs):
        raise RuntimeError("boom")

    module = types.ModuleType("Quartz")
    module.CGEventCreateKeyboardEvent = raise_exc
    module.CGEventPost = raise_exc
    module.kCGHIDEventTap = 0
    monkeypatch.setitem(sys.modules, "Quartz", module)

    keyboard = importlib.import_module("os_ai_os_macos.keyboard")

    # Не должно бросить исключение
    keyboard._press_keycode_safe(36)


def test_type_multiline_uses_clipboard_paste(monkeypatch):
    # Load main shim to ensure we route through computer tool
    import importlib.util, sys
    from pathlib import Path
    proj_root = Path(__file__).resolve().parents[2]
    main_path = proj_root / "main.py"
    if str(proj_root) not in sys.path:
        sys.path.insert(0, str(proj_root))
    spec = importlib.util.spec_from_file_location("agent_core_main", str(main_path))
    assert spec and spec.loader
    main = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(main)  # type: ignore

    # Monkeypatch clipboard and pyautogui
    pasted = {"hotkey": []}

    class _Clip:
        _buf = ""
        @staticmethod
        def paste():
            return _Clip._buf
        @staticmethod
        def copy(v):
            _Clip._buf = v

    def hotkey(*keys):
        pasted["hotkey"].append(tuple(keys))

    def write(text, interval=0.0):
        # Should not be used for multiline/code path
        pasted["write_used"] = True

    monkeypatch.setattr(main, "pyautogui", type("P", (), {"hotkey": hotkey, "write": write}))
    monkeypatch.setitem(sys.modules, "pyperclip", _Clip)

    text = "line1\nline2()"
    res = main.handle_computer_action("type", {"text": text})

    # Check platform-appropriate paste key: command on macOS, ctrl on Windows/Linux
    expected_modifier = "command" if sys.platform == "darwin" else "ctrl"
    assert pasted["hotkey"] == [(expected_modifier, "v")]
    assert "write_used" not in pasted
    assert any("pasted" in c.get("text", "") for c in res)


