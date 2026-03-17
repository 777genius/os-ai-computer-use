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


def test_linux_drivers_loaded():
    """Basic contract: drivers load and have all required methods."""
    from os_ai_os.api import get_drivers
    drv = get_drivers()
    assert hasattr(drv.mouse, "move_to")
    assert hasattr(drv.keyboard, "press_enter")
    assert hasattr(drv.keyboard, "press_combo")
    assert hasattr(drv.keyboard, "type_text")
    assert hasattr(drv.mouse, "click")
    assert hasattr(drv.mouse, "scroll")
    assert hasattr(drv.mouse, "drag")
    assert hasattr(drv.screen, "screenshot")
    assert hasattr(drv.overlay, "highlight")
    assert hasattr(drv.overlay, "process_events")
    assert hasattr(drv.sound, "play_click")
    assert hasattr(drv.sound, "play_done")
    assert hasattr(drv.permissions, "has_input_access")
    assert drv.capabilities.supports_synthetic_input is True


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
    assert hasattr(img, "size")  # PIL.Image has .size
    w, h = img.size
    assert w > 0 and h > 0


def test_keyboard_type_text():
    """type_text does not crash under xvfb (no target window, just verify no exception)."""
    from os_ai_os.api import get_drivers
    # Short ASCII text — pyautogui.write() should work without errors
    get_drivers().keyboard.type_text("hi", wpm=9999)


def test_keyboard_press_enter():
    """press_enter does not crash under xvfb."""
    from os_ai_os.api import get_drivers
    get_drivers().keyboard.press_enter()


def test_keyboard_press_combo():
    """press_combo with standard keys does not crash."""
    from os_ai_os.api import get_drivers
    get_drivers().keyboard.press_combo(("ctrl", "a"))


def test_mouse_move_and_click():
    """Mouse move and click do not crash under xvfb."""
    from os_ai_os.api import get_drivers
    drv = get_drivers()
    drv.mouse.move_to(100, 100)
    drv.mouse.click(button="left", clicks=1)


def test_mouse_scroll():
    """Mouse scroll does not crash under xvfb."""
    from os_ai_os.api import get_drivers
    get_drivers().mouse.scroll(dy=-3)


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


def test_permissions_under_xvfb():
    """Under xvfb, DISPLAY is set so input access should be True."""
    from os_ai_os.api import get_drivers
    drv = get_drivers()
    assert drv.permissions.has_input_access() is True


def test_dpi_scale_default():
    """Without GDK_SCALE set, DPI scale defaults to 1.0."""
    import os
    from os_ai_os.api import get_drivers
    if not os.environ.get("GDK_SCALE"):
        assert get_drivers().capabilities.dpi_scale == 1.0
