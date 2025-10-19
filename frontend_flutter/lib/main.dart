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

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeStore()),
      ],
      child: const AppRoot(),
    ),
  );
}
