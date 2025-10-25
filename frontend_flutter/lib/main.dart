import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:frontend_flutter/src/app/di/locator.dart';
import 'package:frontend_flutter/src/app/config/app_config.dart';
import 'package:frontend_flutter/src/app/services/secure_storage_service.dart';
import 'package:frontend_flutter/src/presentation/app/app.dart';
import 'package:frontend_flutter/src/presentation/stores/theme_store.dart';
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

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeStore()),
        ChangeNotifierProvider(create: (_) => initialConfig),
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

    return AppConfig(
      anthropicApiKey: keys['anthropic'],
      openaiApiKey: keys['openai'],
    );
  } catch (e) {
    debugPrint('Error loading initial config: $e');
    return AppConfig(); // Return default config
  }
}

Future<void> _initDesktop() async {
  // Note: This function only runs on desktop platforms (not Web)
  // All desktop-specific imports are done here to avoid web compilation errors

  // This would normally use conditional imports, but for simplicity
  // we just skip desktop features on web for now
  // Desktop initialization would go here when running on actual desktop
  debugPrint('Desktop initialization skipped (will be handled by launcher on desktop)');
}
