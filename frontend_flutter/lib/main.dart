import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:frontend_flutter/src/app/di/locator.dart';
import 'package:frontend_flutter/src/presentation/app/app.dart';
import 'package:frontend_flutter/src/presentation/stores/theme_store.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  await Hive.initFlutter();

  // Desktop-only initialization
  if (!kIsWeb) {
    await _initDesktop();
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

Future<void> _initDesktop() async {
  // Note: This function only runs on desktop platforms (not Web)
  // All desktop-specific imports are done here to avoid web compilation errors

  // This would normally use conditional imports, but for simplicity
  // we just skip desktop features on web for now
  // Desktop initialization would go here when running on actual desktop
  debugPrint('Desktop initialization skipped (will be handled by launcher on desktop)');
}
