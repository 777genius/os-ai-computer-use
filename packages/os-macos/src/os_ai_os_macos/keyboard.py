# macOS virtual key codes
_VK_RETURN = 36            # Main Return key
_VK_KEYPAD_ENTER = 76      # Keypad Enter


def _press_keycode_safe(keycode: int) -> bool:
    """Press a key via Quartz. Returns True on success, False on failure."""
    try:
        from Quartz import CGEventCreateKeyboardEvent, CGEventPost, kCGHIDEventTap
        down = CGEventCreateKeyboardEvent(None, keycode, True)
        up = CGEventCreateKeyboardEvent(None, keycode, False)
        CGEventPost(kCGHIDEventTap, down)
        CGEventPost(kCGHIDEventTap, up)
        return True
    except Exception:
        return False


def press_enter_mac() -> None:
    """Reliably press the Return/Enter on macOS using Quartz events.

    Tries the main Return key first, falls back to Keypad Enter only if first fails.
    """
    if not _press_keycode_safe(_VK_RETURN):
        _press_keycode_safe(_VK_KEYPAD_ENTER)
