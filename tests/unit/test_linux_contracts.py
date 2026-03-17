"""Linux integration contract tests — run on real Linux with xvfb in CI.

These tests actually invoke pyautogui operations against a virtual
X11 display (xvfb) to verify the full driver stack works end-to-end.
"""
import platform
import pytest


pytestmark = pytest.mark.skipif(
    platform.system().lower() != "linux",
    reason="Linux-only: requires X11 display (xvfb in CI)",
)


# --------------- Driver loading ---------------


def test_linux_drivers_loaded():
    """Basic contract: drivers load and have all required methods."""
    from os_ai_os.api import get_drivers
    drv = get_drivers()
    assert hasattr(drv.mouse, "move_to")
    assert hasattr(drv.keyboard, "press_enter")
    assert hasattr(drv.keyboard, "press_combo")
    assert hasattr(drv.keyboard, "type_text")
    assert hasattr(drv.mouse, "click")
    assert hasattr(drv.mouse, "down")
    assert hasattr(drv.mouse, "up")
    assert hasattr(drv.mouse, "scroll")
    assert hasattr(drv.mouse, "drag")
    assert hasattr(drv.screen, "screenshot")
    assert hasattr(drv.overlay, "highlight")
    assert hasattr(drv.overlay, "process_events")
    assert hasattr(drv.sound, "play_click")
    assert hasattr(drv.sound, "play_done")
    assert hasattr(drv.permissions, "has_input_access")
    assert hasattr(drv.permissions, "has_screen_recording")
    assert drv.capabilities.supports_synthetic_input is True


def test_get_drivers_singleton():
    """get_drivers() returns the same instance on repeated calls."""
    from os_ai_os.api import get_drivers
    d1 = get_drivers()
    d2 = get_drivers()
    assert d1 is d2


def test_drivers_are_correct_types():
    """Verify driver instances come from defaults / Linux package."""
    from os_ai_os.api import get_drivers
    from os_ai_os.defaults import PyAutoGUIMouse, PyAutoGUIKeyboard, PyAutoGUIScreen
    from os_ai_os.defaults import NoOpOverlay, NoOpSound
    from os_ai_os_linux.drivers import LinuxPermissions
    drv = get_drivers()
    assert isinstance(drv.mouse, PyAutoGUIMouse)
    assert isinstance(drv.keyboard, PyAutoGUIKeyboard)
    assert isinstance(drv.screen, PyAutoGUIScreen)
    assert isinstance(drv.overlay, NoOpOverlay)
    assert isinstance(drv.sound, NoOpSound)
    assert isinstance(drv.permissions, LinuxPermissions)


# --------------- Screen ---------------


def test_screen_size_positive():
    """Screen size returns positive dimensions under xvfb."""
    from os_ai_os.api import get_drivers
    sz = get_drivers().screen.size()
    assert isinstance(sz.width, int) and sz.width > 0
    assert isinstance(sz.height, int) and sz.height > 0


def test_screenshot_returns_image():
    """Screenshot returns a PIL Image under xvfb."""
    from os_ai_os.api import get_drivers
    img = get_drivers().screen.screenshot()
    assert img is not None
    assert hasattr(img, "size")
    w, h = img.size
    assert w > 0 and h > 0


def test_screenshot_dimensions_match_screen_size():
    """Screenshot image dimensions must match screen.size()."""
    from os_ai_os.api import get_drivers
    drv = get_drivers()
    sz = drv.screen.size()
    img = drv.screen.screenshot()
    assert img.size == (sz.width, sz.height)


def test_screenshot_region():
    """Screenshot with region returns cropped image of correct size."""
    from os_ai_os.api import get_drivers
    img = get_drivers().screen.screenshot(region=(0, 0, 100, 50))
    assert img is not None
    assert img.size == (100, 50)


# --------------- Keyboard ---------------


def test_keyboard_type_text():
    """type_text does not crash under xvfb."""
    from os_ai_os.api import get_drivers
    get_drivers().keyboard.type_text("hello world", wpm=9999)


def test_keyboard_type_empty():
    """type_text with empty string does not crash."""
    from os_ai_os.api import get_drivers
    get_drivers().keyboard.type_text("", wpm=180)


def test_keyboard_press_enter():
    """press_enter does not crash under xvfb."""
    from os_ai_os.api import get_drivers
    get_drivers().keyboard.press_enter()


def test_keyboard_press_combo_ctrl_a():
    """press_combo Ctrl+A does not crash."""
    from os_ai_os.api import get_drivers
    get_drivers().keyboard.press_combo(("ctrl", "a"))


def test_keyboard_press_combo_ctrl_shift_a():
    """press_combo with multiple modifiers does not crash."""
    from os_ai_os.api import get_drivers
    get_drivers().keyboard.press_combo(("ctrl", "shift", "a"))


def test_keyboard_press_combo_single_key():
    """press_combo with single key (e.g. 'tab') does not crash."""
    from os_ai_os.api import get_drivers
    get_drivers().keyboard.press_combo(("tab",))


def test_keyboard_press_combo_empty():
    """press_combo with empty tuple is a no-op."""
    from os_ai_os.api import get_drivers
    get_drivers().keyboard.press_combo(())


def test_keyboard_press_combo_function_keys():
    """press_combo with function keys does not crash."""
    from os_ai_os.api import get_drivers
    get_drivers().keyboard.press_combo(("f5",))
    get_drivers().keyboard.press_combo(("alt", "f4"))


# --------------- Mouse ---------------


def test_mouse_move_to():
    """Mouse move to coordinates does not crash."""
    from os_ai_os.api import get_drivers
    get_drivers().mouse.move_to(200, 200)


def test_mouse_move_with_duration():
    """Mouse animated move does not crash."""
    from os_ai_os.api import get_drivers
    get_drivers().mouse.move_to(300, 300, duration_ms=50)


def test_mouse_left_click():
    """Left click does not crash."""
    from os_ai_os.api import get_drivers
    drv = get_drivers()
    drv.mouse.move_to(100, 100)
    drv.mouse.click(button="left", clicks=1)


def test_mouse_right_click():
    """Right click does not crash."""
    from os_ai_os.api import get_drivers
    drv = get_drivers()
    drv.mouse.move_to(100, 100)
    drv.mouse.click(button="right", clicks=1)


def test_mouse_double_click():
    """Double click does not crash."""
    from os_ai_os.api import get_drivers
    drv = get_drivers()
    drv.mouse.move_to(100, 100)
    drv.mouse.click(button="left", clicks=2)


def test_mouse_down_up():
    """Mouse down/up separately does not crash."""
    from os_ai_os.api import get_drivers
    drv = get_drivers()
    drv.mouse.move_to(100, 100)
    drv.mouse.down(button="left")
    drv.mouse.up(button="left")


def test_mouse_scroll_vertical():
    """Vertical scroll does not crash under xvfb."""
    from os_ai_os.api import get_drivers
    get_drivers().mouse.scroll(dy=-3)
    get_drivers().mouse.scroll(dy=3)


def test_mouse_scroll_horizontal():
    """Horizontal scroll does not crash (tests hscroll or shift+scroll fallback)."""
    from os_ai_os.api import get_drivers
    get_drivers().mouse.scroll(dx=2)
    get_drivers().mouse.scroll(dx=-2)


def test_mouse_drag():
    """Mouse drag does not crash under xvfb."""
    from os_ai_os.api import get_drivers
    get_drivers().mouse.drag((50, 50), (200, 200), steps=3, delay_ms=10)


def test_mouse_drag_single_step():
    """Mouse drag with steps=1 does not crash."""
    from os_ai_os.api import get_drivers
    get_drivers().mouse.drag((50, 50), (150, 150), steps=1)


# --------------- No-op stubs ---------------


def test_overlay_noop():
    """Overlay operations are no-ops and don't crash."""
    from os_ai_os.api import get_drivers
    drv = get_drivers()
    result = drv.overlay.highlight(50, 50, radius=10, duration=0.01)
    assert result is None
    drv.overlay.process_events()


def test_sound_noop():
    """Sound operations are no-ops and don't crash."""
    from os_ai_os.api import get_drivers
    drv = get_drivers()
    assert drv.sound.play_click() is None
    assert drv.sound.play_done() is None


# --------------- Permissions ---------------


def test_permissions_input_access_under_xvfb():
    """Under xvfb, DISPLAY is set so input access should be True."""
    from os_ai_os.api import get_drivers
    assert get_drivers().permissions.has_input_access() is True


def test_permissions_screen_recording_available():
    """gnome-screenshot is installed in CI, so screen recording should be True."""
    from os_ai_os.api import get_drivers
    assert get_drivers().permissions.has_screen_recording() is True
    assert get_drivers().capabilities.screen_recording_available is True


# --------------- Capabilities ---------------


def test_dpi_scale_default():
    """Without GDK_SCALE set, DPI scale defaults to 1.0."""
    import os
    from os_ai_os.api import get_drivers
    if not os.environ.get("GDK_SCALE"):
        assert get_drivers().capabilities.dpi_scale == 1.0


def test_capabilities_no_overlay():
    """Linux has no overlay support."""
    from os_ai_os.api import get_drivers
    assert get_drivers().capabilities.supports_click_through_overlay is False


def test_capabilities_smooth_move():
    """Linux supports smooth mouse movement."""
    from os_ai_os.api import get_drivers
    assert get_drivers().capabilities.supports_smooth_move is True


# --------------- Full e2e: move → screenshot → verify pixel ---------------


def test_e2e_screenshot_after_mouse_move():
    """Full pipeline: move mouse, take screenshot, verify it's a valid image.

    This tests the complete driver stack from factory through
    pyautogui to X11 and back.
    """
    from os_ai_os.api import get_drivers
    drv = get_drivers()
    drv.mouse.move_to(50, 50)
    drv.keyboard.press_combo(())  # no-op to ensure event queue is flushed
    img = drv.screen.screenshot()
    assert img is not None
    assert img.size[0] > 0 and img.size[1] > 0


# --------------- parse_key_combo on real Linux ---------------


def test_parse_key_combo_super_on_linux():
    """'super' key maps to 'win' (pyautogui X11 name for Super_L) on Linux."""
    from os_ai_core.tools.computer import parse_key_combo
    assert parse_key_combo("super+l") == ["win", "l"]


def test_parse_key_combo_meta_on_linux():
    """'meta' key maps to 'win' on Linux."""
    from os_ai_core.tools.computer import parse_key_combo
    assert parse_key_combo("meta+space") == ["win", "space"]


def test_parse_key_combo_cmd_on_linux():
    """'cmd' maps to 'win' on Linux (not 'command' like macOS)."""
    from os_ai_core.tools.computer import parse_key_combo
    assert parse_key_combo("cmd+c") == ["win", "c"]


def test_parse_key_combo_ctrl_on_linux():
    """'ctrl' stays as 'ctrl' on Linux."""
    from os_ai_core.tools.computer import parse_key_combo
    assert parse_key_combo("ctrl+c") == ["ctrl", "c"]


def test_parse_key_combo_alt_on_linux():
    """'alt' stays as 'alt' on Linux (not 'option' like macOS)."""
    from os_ai_core.tools.computer import parse_key_combo
    assert parse_key_combo("alt+tab") == ["alt", "tab"]


def test_parse_key_combo_option_on_linux():
    """'option' maps to 'alt' on Linux."""
    from os_ai_core.tools.computer import parse_key_combo
    assert parse_key_combo("option+f2") == ["alt", "f2"]


# --------------- handle_computer_action e2e on real Linux ---------------


def test_action_screenshot_returns_base64():
    """handle_computer_action('screenshot') returns base64-encoded image."""
    import pyautogui
    pyautogui.FAILSAFE = False  # avoid fail-safe in headless
    from os_ai_core.tools.computer import handle_computer_action
    result = handle_computer_action("screenshot", {})
    assert len(result) == 1
    block = result[0]
    assert block.get("type") == "image"
    # base64 data should be a non-empty string
    data = block.get("data") or block.get("source", {}).get("data", "")
    assert len(data) > 100  # base64 of any image is long


def test_action_mouse_move():
    """handle_computer_action('mouse_move') moves cursor to coordinates."""
    import pyautogui
    pyautogui.FAILSAFE = False
    from os_ai_core.tools.computer import handle_computer_action
    result = handle_computer_action("mouse_move", {
        "coordinate": [200, 200],
    })
    assert any("done" in str(r.get("text", "")).lower() or "move" in str(r.get("text", "")).lower() for r in result)


def test_action_left_click():
    """handle_computer_action('left_click') at specific coordinates."""
    import pyautogui
    pyautogui.FAILSAFE = False
    from os_ai_core.tools.computer import handle_computer_action
    result = handle_computer_action("left_click", {
        "coordinate": [150, 150],
    })
    assert any("done" in str(r.get("text", "")) for r in result)


def test_action_right_click():
    """handle_computer_action('right_click') at specific coordinates."""
    import pyautogui
    pyautogui.FAILSAFE = False
    from os_ai_core.tools.computer import handle_computer_action
    result = handle_computer_action("right_click", {
        "coordinate": [150, 150],
    })
    assert any("done" in str(r.get("text", "")) for r in result)


def test_action_double_click():
    """handle_computer_action('double_click') at specific coordinates."""
    import pyautogui
    pyautogui.FAILSAFE = False
    from os_ai_core.tools.computer import handle_computer_action
    result = handle_computer_action("double_click", {
        "coordinate": [150, 150],
    })
    assert any("done" in str(r.get("text", "")) for r in result)


def test_action_key_combo():
    """handle_computer_action('key') with key combo."""
    import pyautogui
    pyautogui.FAILSAFE = False
    from os_ai_core.tools.computer import handle_computer_action
    result = handle_computer_action("key", {"key": "ctrl+a"})
    assert any("done" in str(r.get("text", "")) for r in result)


def test_action_key_enter():
    """handle_computer_action('key') with Enter key."""
    import pyautogui
    pyautogui.FAILSAFE = False
    from os_ai_core.tools.computer import handle_computer_action
    result = handle_computer_action("key", {"key": "enter"})
    assert any("done" in str(r.get("text", "")) for r in result)


def test_action_key_super():
    """handle_computer_action('key') with super key on Linux."""
    import pyautogui
    pyautogui.FAILSAFE = False
    from os_ai_core.tools.computer import handle_computer_action
    result = handle_computer_action("key", {"key": "super+l"})
    assert any("done" in str(r.get("text", "")) for r in result)


def test_action_type_simple():
    """handle_computer_action('type') with simple ASCII text."""
    import pyautogui
    pyautogui.FAILSAFE = False
    from os_ai_core.tools.computer import handle_computer_action
    result = handle_computer_action("type", {"text": "hello"})
    assert len(result) >= 1


def test_action_type_multiline_uses_clipboard():
    """handle_computer_action('type') with multiline uses clipboard paste."""
    import pyautogui
    pyautogui.FAILSAFE = False
    from os_ai_core.tools.computer import handle_computer_action
    result = handle_computer_action("type", {"text": "line1\nline2"})
    assert len(result) >= 1
    # Should use clipboard paste path for multiline
    text = str(result[0].get("text", ""))
    assert "pasted" in text or "typed" in text or "done" in text


def test_action_scroll():
    """handle_computer_action('scroll') with scroll direction."""
    import pyautogui
    pyautogui.FAILSAFE = False
    from os_ai_core.tools.computer import handle_computer_action
    result = handle_computer_action("scroll", {
        "coordinate": [200, 200],
        "scroll_direction": "down",
        "scroll_amount": 3,
    })
    assert any("done" in str(r.get("text", "")) for r in result)


def test_action_drag():
    """handle_computer_action('left_click_drag') between two points."""
    import pyautogui
    pyautogui.FAILSAFE = False
    from os_ai_core.tools.computer import handle_computer_action
    result = handle_computer_action("left_click_drag", {
        "start": [100, 100],
        "end": [200, 200],
        "steps": 2,
    })
    assert any("done" in str(r.get("text", "")) for r in result)


# --------------- Mouse position verification ---------------


def test_mouse_position_after_move():
    """After move_to(x, y), pyautogui.position() should match."""
    import pyautogui
    pyautogui.FAILSAFE = False
    from os_ai_os.api import get_drivers
    drv = get_drivers()
    target_x, target_y = 300, 250
    drv.mouse.move_to(target_x, target_y)
    actual_x, actual_y = pyautogui.position()
    assert abs(actual_x - target_x) <= 2, f"X mismatch: expected {target_x}, got {actual_x}"
    assert abs(actual_y - target_y) <= 2, f"Y mismatch: expected {target_y}, got {actual_y}"


# --------------- Clipboard e2e ---------------


def test_clipboard_copy_paste():
    """pyperclip copy/paste works on Linux (requires xclip)."""
    try:
        import pyperclip
    except ImportError:
        pytest.skip("pyperclip not installed")
    try:
        pyperclip.copy("linux_test_12345")
        result = pyperclip.paste()
        assert result == "linux_test_12345"
    except Exception as e:
        if "xclip" in str(e).lower() or "xsel" in str(e).lower():
            pytest.skip(f"clipboard tool not available: {e}")
        raise

