"""Tests for LinuxPermissions, _detect_scale, and factory.py Linux branch.

These tests use monkeypatch/mocks and can run on ANY platform.
"""
from __future__ import annotations

import importlib
import logging
import os
import sys
from unittest.mock import patch

import pytest


# --------------- LinuxPermissions ---------------


class TestLinuxPermissions:
    def _make(self):
        from os_ai_os_linux.drivers import LinuxPermissions
        return LinuxPermissions()

    def test_has_input_access_display_set(self, monkeypatch):
        monkeypatch.setenv("DISPLAY", ":0")
        monkeypatch.delenv("WAYLAND_DISPLAY", raising=False)
        assert self._make().has_input_access() is True

    def test_has_input_access_display_unset(self, monkeypatch):
        monkeypatch.delenv("DISPLAY", raising=False)
        monkeypatch.delenv("WAYLAND_DISPLAY", raising=False)
        assert self._make().has_input_access() is False

    def test_has_input_access_wayland_only(self, monkeypatch):
        monkeypatch.delenv("DISPLAY", raising=False)
        monkeypatch.setenv("WAYLAND_DISPLAY", "wayland-0")
        assert self._make().has_input_access() is False

    def test_has_input_access_xwayland(self, monkeypatch):
        monkeypatch.setenv("DISPLAY", ":0")
        monkeypatch.setenv("WAYLAND_DISPLAY", "wayland-0")
        assert self._make().has_input_access() is True

    def test_has_screen_recording_scrot(self):
        with patch("shutil.which", side_effect=lambda t: "/usr/bin/scrot" if t == "scrot" else None):
            assert self._make().has_screen_recording() is True

    def test_has_screen_recording_gnome_screenshot(self):
        with patch("shutil.which", side_effect=lambda t: "/usr/bin/gnome-screenshot" if t == "gnome-screenshot" else None):
            assert self._make().has_screen_recording() is True

    def test_has_screen_recording_neither(self):
        with patch("shutil.which", return_value=None):
            assert self._make().has_screen_recording() is False

    def test_ensure_input_access_logs_when_no_display(self, monkeypatch, caplog):
        monkeypatch.delenv("DISPLAY", raising=False)
        monkeypatch.delenv("WAYLAND_DISPLAY", raising=False)
        with caplog.at_level(logging.WARNING, logger="os_ai"):
            self._make().ensure_input_access()
        assert "X11" in caplog.text or "DISPLAY" in caplog.text

    def test_ensure_screen_recording_logs_when_no_tool(self, caplog):
        with patch("shutil.which", return_value=None):
            with caplog.at_level(logging.WARNING, logger="os_ai"):
                self._make().ensure_screen_recording()
        assert "scrot" in caplog.text


# --------------- _detect_scale ---------------


class TestDetectScale:
    def _call(self):
        from os_ai_os_linux.drivers import _detect_scale
        return _detect_scale()

    def test_unset_returns_1(self, monkeypatch):
        monkeypatch.delenv("GDK_SCALE", raising=False)
        assert self._call() == 1.0

    def test_integer_2(self, monkeypatch):
        monkeypatch.setenv("GDK_SCALE", "2")
        assert self._call() == 2.0

    def test_float_2_5(self, monkeypatch):
        monkeypatch.setenv("GDK_SCALE", "2.5")
        assert self._call() == 2.5

    def test_suffix_2x(self, monkeypatch):
        monkeypatch.setenv("GDK_SCALE", "2x")
        assert self._call() == 2.0

    def test_suffix_2X(self, monkeypatch):
        monkeypatch.setenv("GDK_SCALE", "2X")
        assert self._call() == 2.0

    def test_whitespace(self, monkeypatch):
        monkeypatch.setenv("GDK_SCALE", "  2  ")
        assert self._call() == 2.0

    def test_invalid_string(self, monkeypatch, caplog):
        monkeypatch.setenv("GDK_SCALE", "auto")
        with caplog.at_level(logging.WARNING, logger="os_ai"):
            assert self._call() == 1.0
        assert "Could not parse GDK_SCALE" in caplog.text

    def test_zero_invalid(self, monkeypatch, caplog):
        monkeypatch.setenv("GDK_SCALE", "0")
        with caplog.at_level(logging.WARNING, logger="os_ai"):
            assert self._call() == 1.0
        assert "Could not parse GDK_SCALE" in caplog.text

    def test_negative_invalid(self, monkeypatch, caplog):
        monkeypatch.setenv("GDK_SCALE", "-2")
        with caplog.at_level(logging.WARNING, logger="os_ai"):
            assert self._call() == 1.0
        assert "Could not parse GDK_SCALE" in caplog.text

    def test_empty_string(self, monkeypatch):
        monkeypatch.setenv("GDK_SCALE", "")
        assert self._call() == 1.0


# --------------- factory.py Linux branch ---------------


class TestFactoryLinuxBranch:
    def test_no_display_raises(self, monkeypatch):
        from os_ai_os.platform.factory import build_platform
        monkeypatch.delenv("DISPLAY", raising=False)
        monkeypatch.delenv("WAYLAND_DISPLAY", raising=False)
        with pytest.raises(RuntimeError, match="No X11 display"):
            build_platform("linux")

    def test_wayland_hint_in_error(self, monkeypatch):
        from os_ai_os.platform.factory import build_platform
        monkeypatch.delenv("DISPLAY", raising=False)
        monkeypatch.setenv("WAYLAND_DISPLAY", "wayland-0")
        with pytest.raises(RuntimeError) as exc:
            build_platform("linux")
        assert "Wayland" in str(exc.value)
        assert "XWayland" in str(exc.value)

    def test_unsupported_platform_raises(self):
        from os_ai_os.platform.factory import build_platform
        with pytest.raises(RuntimeError, match="Unsupported platform"):
            build_platform("freebsd")


# --------------- parse_key_combo super/meta aliases ---------------


class TestParseKeyComboAliases:
    """Test super/meta key aliases — works on any platform."""

    def _parse(self, combo: str):
        from os_ai_core.tools.computer import parse_key_combo
        return parse_key_combo(combo)

    def test_super_alias(self):
        result = self._parse("super+x")
        assert result[0] in ("command", "win")  # command on mac, win on linux/windows
        assert result[1] == "x"

    def test_meta_alias(self):
        result = self._parse("meta+c")
        assert result[0] in ("command", "win")
        assert result[1] == "c"

    def test_super_resolves_same_as_cmd(self):
        r1 = self._parse("super+a")
        r2 = self._parse("cmd+a")
        assert r1 == r2

    def test_meta_resolves_same_as_command(self):
        r1 = self._parse("meta+b")
        r2 = self._parse("command+b")
        assert r1 == r2

    def test_ctrl_shift_unchanged(self):
        assert self._parse("ctrl+shift+k") == ["ctrl", "shift", "k"]

    def test_enter_return_aliases(self):
        assert self._parse("enter") == ["enter"]
        assert self._parse("return") == ["enter"]


# --------------- defaults.py: scroll fallback, drag steps ---------------


class TestDefaultsScrollFallback:
    """Test PyAutoGUIMouse.scroll() hscroll→shift+scroll fallback."""

    def test_horizontal_scroll_uses_hscroll(self):
        from os_ai_os.defaults import PyAutoGUIMouse
        mouse = PyAutoGUIMouse()
        calls = []
        with patch("pyautogui.hscroll", side_effect=lambda n: calls.append(("hscroll", n))):
            mouse.scroll(dx=3)
        assert calls == [("hscroll", 3)]

    def test_horizontal_scroll_fallback_shift(self):
        from os_ai_os.defaults import PyAutoGUIMouse
        mouse = PyAutoGUIMouse()
        calls = []
        with patch("pyautogui.hscroll", side_effect=AttributeError), \
             patch("pyautogui.keyDown", side_effect=lambda k: calls.append(("kd", k))), \
             patch("pyautogui.scroll", side_effect=lambda n: calls.append(("scroll", n))), \
             patch("pyautogui.keyUp", side_effect=lambda k: calls.append(("ku", k))):
            mouse.scroll(dx=5)
        assert calls == [("kd", "shift"), ("scroll", 5), ("ku", "shift")]

    def test_vertical_scroll(self):
        from os_ai_os.defaults import PyAutoGUIMouse
        mouse = PyAutoGUIMouse()
        calls = []
        with patch("pyautogui.scroll", side_effect=lambda n: calls.append(("scroll", n))):
            mouse.scroll(dy=-3)
        assert calls == [("scroll", -3)]


class TestDefaultsDragSteps:
    """Test PyAutoGUIMouse.drag() produces correct number of intermediate moves."""

    def test_drag_single_step(self):
        from os_ai_os.defaults import PyAutoGUIMouse
        mouse = PyAutoGUIMouse()
        moves = []
        with patch("pyautogui.moveTo", side_effect=lambda x, y, **kw: moves.append((x, y))), \
             patch("pyautogui.mouseDown"), \
             patch("pyautogui.mouseUp"):
            mouse.drag((0, 0), (100, 100), steps=1)
        # start move + 1 end move
        assert moves == [(0, 0), (100, 100)]

    def test_drag_three_steps(self):
        from os_ai_os.defaults import PyAutoGUIMouse
        mouse = PyAutoGUIMouse()
        moves = []
        with patch("pyautogui.moveTo", side_effect=lambda x, y, **kw: moves.append((x, y))), \
             patch("pyautogui.mouseDown"), \
             patch("pyautogui.mouseUp"):
            mouse.drag((0, 0), (300, 300), steps=3)
        # start + 3 intermediate moves (at 1/3, 2/3, 3/3)
        assert len(moves) == 4  # 1 start + 3 steps
        assert moves[0] == (0, 0)
        assert moves[-1] == (300, 300)
        assert moves[1] == (100, 100)  # 1/3
        assert moves[2] == (200, 200)  # 2/3


# --------------- make_drivers() assembly ---------------


class TestMakeDriversAssembly:
    """Test that make_drivers() returns correctly assembled PlatformDrivers."""

    def test_make_drivers_returns_platform_drivers(self, monkeypatch):
        monkeypatch.setenv("DISPLAY", ":0")
        monkeypatch.delenv("GDK_SCALE", raising=False)
        with patch("shutil.which", return_value="/usr/bin/scrot"):
            from os_ai_os_linux.drivers import make_drivers
            drv = make_drivers()

        from os_ai_os.platform.drivers import PlatformDrivers
        assert isinstance(drv, PlatformDrivers)

    def test_make_drivers_has_all_components(self, monkeypatch):
        monkeypatch.setenv("DISPLAY", ":0")
        monkeypatch.delenv("GDK_SCALE", raising=False)
        with patch("shutil.which", return_value="/usr/bin/scrot"):
            from os_ai_os_linux.drivers import make_drivers
            drv = make_drivers()

        assert drv.mouse is not None
        assert drv.keyboard is not None
        assert drv.screen is not None
        assert drv.overlay is not None
        assert drv.sound is not None
        assert drv.permissions is not None
        assert drv.capabilities is not None

    def test_make_drivers_capabilities_values(self, monkeypatch):
        monkeypatch.setenv("DISPLAY", ":0")
        monkeypatch.setenv("GDK_SCALE", "2")
        with patch("shutil.which", return_value="/usr/bin/scrot"):
            from os_ai_os_linux.drivers import make_drivers
            drv = make_drivers()

        assert drv.capabilities.supports_synthetic_input is True
        assert drv.capabilities.supports_click_through_overlay is False
        assert drv.capabilities.dpi_scale == 2.0
        assert drv.capabilities.screen_recording_available is True

    def test_make_drivers_no_scrot_sets_screen_recording_false(self, monkeypatch):
        monkeypatch.setenv("DISPLAY", ":0")
        with patch("shutil.which", return_value=None):
            from os_ai_os_linux.drivers import make_drivers
            drv = make_drivers()

        assert drv.capabilities.screen_recording_available is False

    def test_make_drivers_uses_linux_permissions(self, monkeypatch):
        monkeypatch.setenv("DISPLAY", ":0")
        with patch("shutil.which", return_value="/usr/bin/scrot"):
            from os_ai_os_linux.drivers import make_drivers, LinuxPermissions
            drv = make_drivers()

        assert isinstance(drv.permissions, LinuxPermissions)


# --------------- NoOp stubs contract ---------------


class TestNoOpStubs:
    """Verify NoOp stubs don't crash and return None."""

    def test_noop_overlay_highlight_returns_none(self):
        from os_ai_os.defaults import NoOpOverlay
        assert NoOpOverlay().highlight(10, 20, radius=5, duration=0.1) is None

    def test_noop_overlay_process_events(self):
        from os_ai_os.defaults import NoOpOverlay
        assert NoOpOverlay().process_events() is None

    def test_noop_sound_play_click(self):
        from os_ai_os.defaults import NoOpSound
        assert NoOpSound().play_click() is None

    def test_noop_sound_play_done(self):
        from os_ai_os.defaults import NoOpSound
        assert NoOpSound().play_done() is None

    def test_always_granted_permissions(self):
        from os_ai_os.defaults import AlwaysGrantedPermissions
        p = AlwaysGrantedPermissions()
        assert p.has_input_access() is True
        assert p.has_screen_recording() is True
        assert p.ensure_input_access() is None
        assert p.ensure_screen_recording() is None


# --------------- computer.py import error handling ---------------


class TestComputerPyAutoGUIImportGuard:
    """Test the try/except around import pyautogui in computer.py."""

    def test_keyerror_on_linux_gives_importerror(self, monkeypatch):
        """Simulate KeyError('DISPLAY') from pyautogui X11 backend on Linux."""
        import importlib
        monkeypatch.setattr("sys.platform", "linux")

        original_import = __builtins__.__import__ if hasattr(__builtins__, '__import__') else __import__

        def fake_import(name, *args, **kwargs):
            if name == "pyautogui":
                raise KeyError("DISPLAY")
            return original_import(name, *args, **kwargs)

        # Remove cached pyautogui and computer modules
        mods_to_remove = [k for k in sys.modules if k.startswith("os_ai_core.tools.computer") or k == "pyautogui"]
        saved = {k: sys.modules.pop(k) for k in mods_to_remove if k in sys.modules}

        try:
            with patch("builtins.__import__", side_effect=fake_import):
                with pytest.raises(ImportError, match="X11 display"):
                    importlib.import_module("os_ai_core.tools.computer")
        finally:
            # Restore modules
            sys.modules.update(saved)

    def test_non_display_error_on_linux_reraises(self, monkeypatch):
        """Non-display exceptions should be re-raised as-is on Linux."""
        import importlib
        monkeypatch.setattr("sys.platform", "linux")

        original_import = __builtins__.__import__ if hasattr(__builtins__, '__import__') else __import__

        def fake_import(name, *args, **kwargs):
            if name == "pyautogui":
                raise RuntimeError("some other error")
            return original_import(name, *args, **kwargs)

        mods_to_remove = [k for k in sys.modules if k.startswith("os_ai_core.tools.computer")]
        saved = {k: sys.modules.pop(k) for k in mods_to_remove if k in sys.modules}

        try:
            with patch("builtins.__import__", side_effect=fake_import):
                with pytest.raises(RuntimeError, match="some other error"):
                    importlib.import_module("os_ai_core.tools.computer")
        finally:
            sys.modules.update(saved)


