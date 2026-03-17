import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:provider/provider.dart';
import 'package:frontend_flutter/src/features/chat/presentation/screen/chat_screen.dart';
import 'package:frontend_flutter/src/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:frontend_flutter/src/features/chat/domain/repositories/chat_repository.dart';
import 'package:frontend_flutter/src/app/services/secure_storage_service.dart';
import 'package:frontend_flutter/src/presentation/settings/first_run_dialog.dart';
import 'package:frontend_flutter/src/presentation/overlay/window_mode_service.dart';
import 'package:get_it/get_it.dart';

/// Shell widget that sits inside MaterialApp tree.
/// Handles first-run dialog, ChatRepository disposal, and global hotkeys.
/// Must be a descendant of MaterialApp to have access to MaterialLocalizations.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  HotKey? _overlayHotKey;
  HotKey? _stopHotKey;
  static const _hotkeyChannel = MethodChannel('com.osai/hotkeys');

  @override
  void initState() {
    super.initState();
    _hotkeyChannel.setMethodCallHandler(_handleNativeHotkey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstRunAndEnterOverlay();
      _registerGlobalHotkeys();
    });
  }

  /// Handle hotkey calls from native macOS side (Ctrl+Esc global monitor).
  Future<dynamic> _handleNativeHotkey(MethodCall call) async {
    switch (call.method) {
      case 'emergencyStop':
        _emergencyStop();
        return null;
      default:
        return null;
    }
  }

  Future<void> _registerGlobalHotkeys() async {
    try {
      // Toggle overlay mode: Cmd+Shift+O (macOS) / Ctrl+Shift+O (Win/Linux)
      _overlayHotKey = HotKey(
        key: PhysicalKeyboardKey.keyO,
        modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
        scope: HotKeyScope.system,
      );
      await hotKeyManager.register(
        _overlayHotKey!,
        keyDownHandler: (_) => _toggleOverlay(),
      );

      // Emergency stop on Windows/Linux (macOS uses native CGEventTap)
      if (!kIsWeb && defaultTargetPlatform != TargetPlatform.macOS) {
        _stopHotKey = HotKey(
          key: PhysicalKeyboardKey.escape,
          modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
          scope: HotKeyScope.system,
        );
        await hotKeyManager.register(
          _stopHotKey!,
          keyDownHandler: (_) => _emergencyStop(),
        );
      }
    } catch (e) {
      debugPrint('Failed to register global hotkey: $e');
    }
  }

  void _emergencyStop() {
    debugPrint('Emergency stop triggered');
    try {
      final repo = context.read<ChatRepository?>();
      repo?.cancelCurrentJob();
    } catch (e) {
      debugPrint('Emergency stop error: $e');
    }
  }

  void _toggleOverlay() {
    try {
      final wms = context.read<WindowModeService>();
      wms.toggleOverlay();
    } catch (e) {
      debugPrint('Failed to toggle overlay: $e');
    }
  }

  Future<void> _checkFirstRunAndEnterOverlay() async {
    try {
      final storage = GetIt.I<SecureStorageService>();
      final hasCompleted = await storage.hasCompletedSetup();

      if (!hasCompleted && mounted) {
        // First run: show setup dialog in normal window mode
        final result = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => const FirstRunDialog(),
        );
        // After saving token → switch to overlay
        if (result == true && mounted) {
          await _enterOverlayMode();
        }
      } else if (hasCompleted && mounted) {
        // Setup already done → start in overlay mode immediately
        await _enterOverlayMode();
      }
    } catch (e) {
      debugPrint('Error checking first run: $e');
    }
  }

  Future<void> _enterOverlayMode() async {
    try {
      final wms = context.read<WindowModeService>();
      await wms.enterOverlay();
    } catch (e) {
      debugPrint('Failed to enter overlay mode: $e');
    }
  }

  @override
  void dispose() {
    _hotkeyChannel.setMethodCallHandler(null);
    try {
      if (_overlayHotKey != null) hotKeyManager.unregister(_overlayHotKey!);
      if (_stopHotKey != null) hotKeyManager.unregister(_stopHotKey!);
    } catch (_) {}
    try {
      final repo = context.read<ChatRepository>();
      if (repo is ChatRepositoryImpl) {
        repo.dispose();
      }
    } catch (e) {
      debugPrint('Error disposing ChatRepository: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ChatScreen reads WindowModeService itself and adapts layout
    return const ChatScreen();
  }
}
