"""Linux platform drivers for OS AI.

Uses shared pyautogui-based defaults from os_ai_os.defaults.
Adds Linux-specific: DPI detection via GDK_SCALE,
Wayland/X11 permission checks, scrot availability check.
"""
from __future__ import annotations

import logging
import os
import shutil

from os_ai_os.defaults import (
    PyAutoGUIMouse,
    PyAutoGUIKeyboard,
    PyAutoGUIScreen,
    NoOpOverlay,
    NoOpSound,
)
from os_ai_os.platform.drivers import PlatformDrivers
from os_ai_os.ports.types import Capabilities

_log = logging.getLogger("os_ai")


class LinuxPermissions:
    """Linux permission checks with Wayland/X11 awareness."""

    def has_input_access(self) -> bool:
        # Pure Wayland without XWayland -> pyautogui cannot work
        if os.environ.get("WAYLAND_DISPLAY") and not os.environ.get("DISPLAY"):
            return False
        return bool(os.environ.get("DISPLAY"))

    def ensure_input_access(self) -> None:
        if not self.has_input_access():
            _log.warning(
                "No X11 display found (DISPLAY not set). "
                "If running under Wayland, ensure XWayland is enabled."
            )

    def has_screen_recording(self) -> bool:
        # pyautogui on Linux uses scrot or gnome-screenshot for screenshots
        return bool(shutil.which("scrot") or shutil.which("gnome-screenshot"))

    def ensure_screen_recording(self) -> None:
        if not self.has_screen_recording():
            _log.warning(
                "Screenshot tool not found. Install scrot: "
                "sudo apt-get install scrot"
            )


def _detect_scale() -> float:
    """Detect Linux display scale via GDK_SCALE env var."""
    raw = os.environ.get("GDK_SCALE", "")
    if not raw:
        return 1.0
    # Strip non-numeric suffix (e.g., "2x" → "2")
    cleaned = raw.strip().rstrip("xX")
    try:
        scale = float(cleaned)
        if scale > 0:
            return scale
    except (ValueError, TypeError):
        pass
    _log.warning("Could not parse GDK_SCALE=%r, using scale=1.0", raw)
    return 1.0


def make_drivers() -> PlatformDrivers:
    perms = LinuxPermissions()
    # Log warnings at creation time so user sees issues early
    perms.ensure_input_access()
    perms.ensure_screen_recording()

    has_screen = perms.has_screen_recording()

    return PlatformDrivers(
        mouse=PyAutoGUIMouse(),
        keyboard=PyAutoGUIKeyboard(),
        screen=PyAutoGUIScreen(),
        overlay=NoOpOverlay(),
        permissions=perms,
        sound=NoOpSound(),
        capabilities=Capabilities(
            supports_synthetic_input=True,
            supports_click_through_overlay=False,
            supports_smooth_move=True,
            dpi_scale=_detect_scale(),
            screen_recording_available=has_screen,
        ),
    )
