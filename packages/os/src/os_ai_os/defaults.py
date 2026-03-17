"""Default OS driver implementations based on pyautogui.

Cross-platform reference adapters for Mouse, Keyboard, Screen,
and no-op stubs for Overlay, Sound, Permissions.
Platform packages may import these directly or override.
"""
from __future__ import annotations

from typing import Optional, Tuple

import time

import pyautogui

from .ports.types import Size


# --------------- Mouse ---------------


class PyAutoGUIMouse:
    """Mouse implementation via pyautogui (works on X11, Win32, Cocoa)."""

    def move_to(self, x: int, y: int, *, duration_ms: int = 0) -> None:
        pyautogui.moveTo(int(x), int(y), duration=max(0.0, float(duration_ms) / 1000.0))

    def click(self, *, button: str = "left", clicks: int = 1) -> None:
        pyautogui.click(button=button, clicks=int(clicks), interval=0.05)

    def down(self, *, button: str = "left") -> None:
        pyautogui.mouseDown(button=button)

    def up(self, *, button: str = "left") -> None:
        pyautogui.mouseUp(button=button)

    def scroll(self, *, dx: int = 0, dy: int = 0) -> None:
        if dy:
            pyautogui.scroll(int(dy))
        if dx:
            try:
                pyautogui.hscroll(int(dx))
            except AttributeError:
                pyautogui.keyDown("shift")
                try:
                    pyautogui.scroll(int(dx))
                finally:
                    pyautogui.keyUp("shift")

    def drag(self, start: Tuple[int, int], end: Tuple[int, int], *, steps: int = 1, delay_ms: int = 0) -> None:
        sx, sy = int(start[0]), int(start[1])
        ex, ey = int(end[0]), int(end[1])
        pyautogui.moveTo(sx, sy)
        pyautogui.mouseDown(button="left")
        if steps <= 1:
            pyautogui.moveTo(ex, ey)
        else:
            for i in range(1, int(steps) + 1):
                nx = int(round(sx + (ex - sx) * (i / float(steps))))
                ny = int(round(sy + (ey - sy) * (i / float(steps))))
                pyautogui.moveTo(nx, ny)
                if delay_ms > 0:
                    time.sleep(max(0.0, float(delay_ms) / 1000.0))
        pyautogui.mouseUp(button="left")


# --------------- Keyboard ---------------


class PyAutoGUIKeyboard:
    """Keyboard implementation via pyautogui (works on X11, Win32, Cocoa)."""

    def press_enter(self) -> None:
        pyautogui.press("enter")

    def press_combo(self, keys: Tuple[str, ...]) -> None:
        if not keys:
            return
        if len(keys) == 1:
            pyautogui.press(keys[0])
        else:
            pyautogui.hotkey(*keys)

    def type_text(self, text: str, *, wpm: int = 180) -> None:
        interval = 0.02
        try:
            cps = max(1.0, float(wpm) * 5.0 / 60.0)
            interval = max(0.0, 1.0 / cps)
        except Exception:
            pass
        pyautogui.write(text, interval=interval)


# --------------- Screen ---------------


class PyAutoGUIScreen:
    """Screen implementation via pyautogui (works on X11, Win32, Cocoa)."""

    def size(self) -> Size:
        w, h = pyautogui.size()
        return Size(width=int(w), height=int(h))

    def screenshot(self, region: Optional[Tuple[int, int, int, int]] = None):
        if region is not None:
            x, y, w, h = region
            return pyautogui.screenshot(region=(int(x), int(y), int(w), int(h)))
        return pyautogui.screenshot()


# --------------- No-op stubs ---------------


class NoOpOverlay:
    """Overlay stub for platforms without native overlay support."""

    def highlight(self, x: int, y: int, *, radius: Optional[int] = None, duration: Optional[float] = None) -> None:
        return None

    def process_events(self) -> None:
        return None


class NoOpSound:
    """Sound stub for platforms without native sound feedback."""

    def play_click(self) -> None:
        return None

    def play_done(self) -> None:
        return None


class AlwaysGrantedPermissions:
    """Permissions stub -- always returns True (Win32, X11 don't need explicit grants)."""

    def has_input_access(self) -> bool:
        return True

    def ensure_input_access(self) -> None:
        return None

    def has_screen_recording(self) -> bool:
        return True

    def ensure_screen_recording(self) -> None:
        return None
