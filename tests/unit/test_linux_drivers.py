"""Tests for LinuxPermissions, _detect_scale, and factory.py Linux branch.

These tests use monkeypatch/mocks and can run on ANY platform.
"""
from __future__ import annotations

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
