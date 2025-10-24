import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:frontend_flutter/src/app/di/locator.dart';
import 'package:frontend_flutter/src/presentation/app/app.dart';
import 'package:frontend_flutter/src/presentation/stores/theme_store.dart';
import 'package:window_manager/window_manager.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' as acrylic;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:tray_manager/tray_manager.dart';
import 'dart:io' show Platform;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  await Hive.initFlutter();

  // Initialize window manager for macOS transparency and control
  await windowManager.ensureInitialized();
  // Initialize acrylic for macOS effects (explicitly disable any vibrancy/darkening)
  await acrylic.Window.initialize();
  await acrylic.Window.setEffect(
    effect: acrylic.WindowEffect.transparent,
    color: const Color(0x00000000),
    dark: false,
  );

  WindowOptions windowOptions = const WindowOptions(
    backgroundColor: Colors.transparent,
    titleBarStyle: TitleBarStyle.hidden,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setHasShadow(false);
    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.setAsFrameless();
    await windowManager.show();
  });

  // Initialize global hotkey manager and register Cmd+G
  await hotKeyManager.unregisterAll();
  final cmdG = HotKey(
    key: PhysicalKeyboardKey.keyG,
    modifiers: [HotKeyModifier.meta],
    scope: HotKeyScope.system,
  );
  await hotKeyManager.register(cmdG, keyDownHandler: (hotKey) async {
    final isVisible = await windowManager.isVisible();
    if (isVisible) {
      await windowManager.hide();
    } else {
      await windowManager.show();
      await windowManager.focus();
    }
  });

  // Initialize system tray (for desktop platforms only)
  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    await _initSystemTray();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeStore()),
      ],
      child: const AppRoot(),
    ),
  );
}

Future<void> _initSystemTray() async {
  await trayManager.setIcon(
    Platform.isWindows
        ? 'assets/icons/tray_icon.ico'
        : 'assets/icons/tray_icon.png',
  );

  Menu menu = Menu(
    items: [
      MenuItem(
        key: 'show_window',
        label: 'Show Window',
      ),
      MenuItem.separator(),
      MenuItem(
        key: 'check_updates',
        label: 'Check for Updates',
      ),
      MenuItem.separator(),
      MenuItem(
        key: 'quit',
        label: 'Quit OS AI',
      ),
    ],
  );

  await trayManager.setContextMenu(menu);

  // Set up tray click handler
  trayManager.addListener(TrayListener());
}

class TrayListener with TrayListenerMixin {
  @override
  void onTrayIconMouseDown() {
    // Single click on tray icon - show window
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    // Right click - show context menu (handled automatically)
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show_window':
        await windowManager.show();
        await windowManager.focus();
        break;
      case 'check_updates':
        // TODO: Implement update check
        debugPrint('Check for updates clicked');
        break;
      case 'quit':
        await windowManager.destroy();
        break;
    }
  }
}
