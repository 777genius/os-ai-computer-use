# Compatibility shim for legacy tests expecting functions in main.
# New architecture implements logic in os_ai_core.tools.computer.

import os
import sys
import glob

# Ensure all workspace package sources are importable when running directly
_ROOT = os.path.dirname(os.path.abspath(__file__))
for _src_dir in glob.glob(os.path.join(_ROOT, "packages", "*", "src")):
    if _src_dir not in sys.path:
        sys.path.insert(0, _src_dir)

from os_ai_core.tools import computer as _computer  # real implementation
from os_ai_os.api import get_drivers

# Expose pyautogui used by the computer tool so test monkeypatching affects real calls
pyautogui = _computer.pyautogui  # type: ignore


def press_enter_mac():
    try:
        get_drivers().keyboard.press_enter()
    except Exception:
        try:
            pyautogui.press("enter")  # type: ignore
        except Exception:
            pass


def handle_computer_action(action, params):  # type: ignore
    # Save original values to restore after call (prevents test pollution)
    _orig_press_enter = getattr(_computer, "press_enter_mac", None)
    _orig_pyautogui = _computer.pyautogui  # type: ignore

    try:
        # Ensure computer module uses (possibly monkeypatched) versions from this module
        # Use globals() to ensure we get the current (possibly monkeypatched) version
        _computer.press_enter_mac = globals()["press_enter_mac"]  # type: ignore
        _computer.pyautogui = globals()["pyautogui"]  # type: ignore
        res = _computer.handle_computer_action(action, params)
        try:
            globals()["LAST_SCREENSHOT_PATH"] = getattr(_computer, "LAST_SCREENSHOT_PATH", "")
        except Exception:
            pass
        return res
    finally:
        # Restore original values to prevent test pollution across tests
        if _orig_press_enter is not None:
            _computer.press_enter_mac = _orig_press_enter  # type: ignore
        elif hasattr(_computer, "press_enter_mac"):
            delattr(_computer, "press_enter_mac")
        _computer.pyautogui = _orig_pyautogui  # type: ignore


if __name__ == "__main__":
    from os_ai_cli.main import main as cli_main
    try:
        code = cli_main()
    except KeyboardInterrupt:
        print("\nInterrupted by user (Ctrl+C)")
        code = 130
    raise SystemExit(code)



