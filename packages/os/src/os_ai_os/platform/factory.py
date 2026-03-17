from __future__ import annotations

import importlib
import os
import platform
import sys
from typing import Optional

from .drivers import PlatformDrivers


def _load_entry_point(ep_group: str, name: str):
    # В PyInstaller entry_points из pyproject.toml отсутствуют — пропускаем.
    if getattr(sys, "frozen", False):
        return None
    try:
        import importlib.metadata as md  # Python 3.8+
    except Exception:
        import importlib_metadata as md  # type: ignore
    for ep in md.entry_points(group=ep_group):  # type: ignore
        if ep.name == name:
            return ep.load()
    return None


def build_platform(explicit: Optional[str] = None) -> PlatformDrivers:
    sysname = (explicit or platform.system()).lower()
    if sysname == "darwin":
        factory = _load_entry_point("os_ai_os.drivers", "darwin")
        if factory is None:
            # direct import fallback
            try:
                mod = importlib.import_module("os_ai_os_macos.drivers")
                factory = getattr(mod, "make_drivers", None)
            except Exception:
                factory = None
        if factory is None:
            raise RuntimeError("macOS drivers not installed: install os_ai_os_macos package")
        return factory()
    if sysname == "windows":
        factory = _load_entry_point("os_ai_os.drivers", "windows")
        if factory is None:
            try:
                mod = importlib.import_module("os_ai_os_windows.drivers")
                factory = getattr(mod, "make_drivers", None)
            except Exception:
                factory = None
        if factory is None:
            raise RuntimeError("Windows drivers not installed: install os_ai_os_windows package")
        return factory()
    if sysname == "linux":
        # Pre-check: pyautogui's X11 backend does
        #   _display = Display(os.environ['DISPLAY'])
        # at module level (_pyautogui_x11.py:182).
        # Without DISPLAY, import raises KeyError -- give a clear message instead.
        if not os.environ.get("DISPLAY"):
            wayland_hint = ""
            if os.environ.get("WAYLAND_DISPLAY"):
                wayland_hint = " Wayland detected but XWayland is not running (no DISPLAY)."
            raise RuntimeError(
                f"No X11 display available (DISPLAY env var not set).{wayland_hint} "
                "OS AI requires X11. If using Wayland, ensure XWayland is enabled."
            )
        factory = _load_entry_point("os_ai_os.drivers", "linux")
        if factory is None:
            try:
                mod = importlib.import_module("os_ai_os_linux.drivers")
                factory = getattr(mod, "make_drivers", None)
            except Exception:
                factory = None
        if factory is None:
            raise RuntimeError("Linux drivers not installed: install os_ai_os_linux package")
        return factory()
    raise RuntimeError(f"Unsupported platform: {sysname}")


