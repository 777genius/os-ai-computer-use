import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:frontend_flutter/src/app/di/locator.dart';
import 'package:frontend_flutter/src/app/config/app_config.dart';
import 'package:frontend_flutter/src/app/services/secure_storage_service.dart';
import 'package:frontend_flutter/src/presentation/app/app.dart';
import 'package:frontend_flutter/src/presentation/stores/theme_store.dart';
import 'package:frontend_flutter/src/presentation/overlay/window_mode_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:get_it/get_it.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  await Hive.initFlutter();

  // Desktop-only initialization
  if (!kIsWeb) {
    await _initDesktop();
  }

  // Load API keys from secure storage
  final initialConfig = await _loadInitialConfig();

  // Create the window mode service (shared across the app)
  final windowModeService = WindowModeService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeStore()),
        ChangeNotifierProvider(create: (_) => initialConfig),
        ChangeNotifierProvider.value(value: windowModeService),
      ],
      child: const AppRoot(),
    ),
  );
}

/// Load API keys and config from secure storage
Future<AppConfig> _loadInitialConfig() async {
  try {
    final storage = GetIt.I<SecureStorageService>();
    final keys = await storage.getAllApiKeys();
    final savedProvider = await storage.getActiveProvider();
    final userPreferences = await storage.getUserPreferences();

    return AppConfig(
      anthropicApiKey: keys['anthropic'],
      openaiApiKey: keys['openai'],
      activeProvider: savedProvider ?? 'anthropic',
      userPreferences: userPreferences,
    );
  } catch (e) {
    debugPrint('Error loading initial config: $e');
    return AppConfig();
  }
}

Future<void> _initDesktop() async {
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(1280, 720),
    minimumSize: Size(600, 400),
    center: true,
    titleBarStyle: TitleBarStyle.hidden,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}
