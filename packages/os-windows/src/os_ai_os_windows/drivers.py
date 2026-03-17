from __future__ import annotations

import time
from typing import Optional, Tuple

import pyautogui

from os_ai_os.platform.drivers import PlatformDrivers
from os_ai_os.ports.mouse import Mouse
from os_ai_os.ports.keyboard import Keyboard
from os_ai_os.ports.screen import Screen
from os_ai_os.ports.overlay import Overlay
from os_ai_os.ports.sound import Sound
from os_ai_os.ports.permissions import Permissions
from os_ai_os.ports.types import Capabilities, Size


class WindowsMouse:
    def move_to(self, x: int, y: int, *, duration_ms: int = 0) -> None:
        dur = max(0.0, float(duration_ms) / 1000.0)
        pyautogui.moveTo(int(x), int(y), duration=dur)

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


class WindowsKeyboard:
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


class WindowsScreen:
    def size(self) -> Size:
        w, h = pyautogui.size()
        return Size(width=int(w), height=int(h))

    def screenshot(self, region: Optional[Tuple[int, int, int, int]] = None):
        if region is not None:
            x, y, w, h = region
            return pyautogui.screenshot(region=(int(x), int(y), int(w), int(h)))
        return pyautogui.screenshot()


class WindowsOverlay:
    def highlight(self, x: int, y: int, *, radius: Optional[int] = None, duration: Optional[float] = None) -> None:
        # No native overlay implementation for Windows in this repo; no-op
        return None

    def process_events(self) -> None:
        return None


class WindowsSound:
    def play_click(self) -> None:
        return None

    def play_done(self) -> None:
        return None


class WindowsPermissions:
    def has_input_access(self) -> bool:
        return True

    def ensure_input_access(self) -> None:
        return None

    def has_screen_recording(self) -> bool:
        return True

    def ensure_screen_recording(self) -> None:
        return None


def make_drivers() -> PlatformDrivers:
    caps = Capabilities(
        supports_synthetic_input=True,
        supports_click_through_overlay=False,
        supports_smooth_move=True,
        dpi_scale=1.0,
        screen_recording_available=True,
    )
    return PlatformDrivers(
        mouse=WindowsMouse(),
        keyboard=WindowsKeyboard(),
        screen=WindowsScreen(),
        overlay=WindowsOverlay(),
        permissions=WindowsPermissions(),
        sound=WindowsSound(),
        capabilities=caps,
    )


