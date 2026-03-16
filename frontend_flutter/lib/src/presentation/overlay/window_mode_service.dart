import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Alignment;
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

/// Service for switching the window between normal and compact overlay modes.
/// macOS: uses MethodChannel to control NSPanel properties natively.
/// Windows/Linux: uses window_manager for alwaysOnTop + resize.
class WindowModeService extends ChangeNotifier {
  static const _channel = MethodChannel('com.osai/window_mode');

  bool _isOverlay = false;
  bool get isOverlay => _isOverlay;

  Size? _savedSize;
  Offset? _savedPosition;

  static const _overlayWidth = 380.0;
  static const _overlayHeight = 520.0;

  Future<void> toggleOverlay() async {
    if (_isOverlay) {
      await exitOverlay();
    } else {
      await enterOverlay();
    }
  }

  Future<void> enterOverlay() async {
    if (_isOverlay) return;

    if (_isMacOS) {
      await _channel.invokeMethod('enterOverlay');
    } else {
      // Windows/Linux: save frame, resize, set always-on-top
      _savedSize = await windowManager.getSize();
      _savedPosition = await windowManager.getPosition();

      await windowManager.setAlwaysOnTop(true);
      await windowManager.setSkipTaskbar(true);
      await windowManager.setSize(const Size(_overlayWidth, _overlayHeight));
      await windowManager.setAlignment(Alignment.bottomRight);
    }

    _isOverlay = true;
    notifyListeners();
  }

  Future<void> exitOverlay() async {
    if (!_isOverlay) return;

    if (_isMacOS) {
      await _channel.invokeMethod('exitOverlay');
    } else {
      // Windows/Linux: restore frame
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setSkipTaskbar(false);
      if (_savedSize != null) {
        await windowManager.setSize(_savedSize!);
      }
      if (_savedPosition != null) {
        await windowManager.setPosition(_savedPosition!);
      }
    }

    _isOverlay = false;
    notifyListeners();
  }

  Future<void> minimizeWindow() async {
    await windowManager.minimize();
  }

  bool get _isMacOS =>
      !kIsWeb && Platform.isMacOS;
}
