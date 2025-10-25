import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend_flutter/src/features/chat/presentation/screen/chat_screen.dart';
import 'package:frontend_flutter/src/features/chat/application/stores/chat_store.dart';
import 'package:frontend_flutter/src/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:frontend_flutter/src/features/chat/domain/repositories/chat_repository.dart';
import 'package:frontend_flutter/src/features/chat/data/datasources/backend_ws_client.dart';
import 'package:frontend_flutter/src/features/chat/data/datasources/backend_rest_client.dart';
import 'package:frontend_flutter/src/app/config/app_config.dart';
import 'package:frontend_flutter/src/app/services/secure_storage_service.dart';
import 'package:frontend_flutter/src/presentation/stores/theme_store.dart';
import 'package:frontend_flutter/src/presentation/theme/app_theme.dart';
import 'package:frontend_flutter/src/presentation/settings/first_run_dialog.dart';
import 'package:frontend_flutter/src/features/chat/data/cache/chat_cache.dart';
import 'package:frontend_flutter/src/features/chat/data/cache/hive_chat_cache.dart';
import 'package:get_it/get_it.dart';

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  @override
  void initState() {
    super.initState();
    // Check if first run after build completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstRun();
    });
  }

  Future<void> _checkFirstRun() async {
    try {
      final storage = GetIt.I<SecureStorageService>();
      final hasCompleted = await storage.hasCompletedSetup();

      if (!hasCompleted && mounted) {
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => const FirstRunDialog(),
        );
      }
    } catch (e) {
      debugPrint('Error checking first run: $e');
    }
  }

  @override
  void dispose() {
    // Clean up ChatRepositoryImpl resources
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
    // Hive инициализируется в main.dart
    final themeStore = context.watch<ThemeStore>();
    final light = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: Colors.blue,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
      extensions: [
        const AppThemeColors(
          userBubbleBg: Color(0xFF1565C0),
          userBubbleFg: Colors.white,
          assistantBubbleBg: Color(0xFFF3F4F6),
          assistantBubbleFg: Color(0xFF111827),
          surfaceBorder: Color(0xFFE5E7EB),
          usageBorder: Color(0xFFFFB74D),
          usageFill: Color(0xFFFFF3E0),
          actionTealBorder: Color(0xFF26A69A),
          actionTealFill: Color(0xFFE0F2F1),
          actionIndigoBorder: Color(0xFF5C6BC0),
          actionIndigoFill: Color(0xFFE8EAF6),
          actionPurpleBorder: Color(0xFF9575CD),
          actionPurpleFill: Color(0xFFF3E5F5),
          actionBlueGreyBorder: Color(0xFF78909C),
          actionBlueGreyFill: Color(0xFFECEFF1),
          actionGreenBorder: Color(0xFF66BB6A),
          actionGreenFill: Color(0xFFE8F5E9),
          actionOrangeBorder: Color(0xFFFFA726),
          actionOrangeFill: Color(0xFFFFF3E0),
        ),
        AppThemeStyles(
          body: const TextStyle(fontSize: 14, height: 1.35),
          bodySmall: const TextStyle(fontSize: 12, height: 1.30),
          caption: const TextStyle(fontSize: 11, height: 1.25),
          labelSmall: const TextStyle(fontSize: 10, height: 1.20, fontWeight: FontWeight.w600),
        ),
      ],
    );
    final dark = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: Colors.blue,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
      extensions: [
        const AppThemeColors(
          userBubbleBg: Color(0xFF1E3A8A),
          userBubbleFg: Colors.white,
          assistantBubbleBg: Color(0xFF111827),
          assistantBubbleFg: Color(0xFFE5E7EB),
          surfaceBorder: Color(0xFF374151),
          usageBorder: Color(0xFFFFB74D),
          usageFill: Color(0xFF3B2F1A),
          actionTealBorder: Color(0xFF26A69A),
          actionTealFill: Color(0xFF0B2F2C),
          actionIndigoBorder: Color(0xFF5C6BC0),
          actionIndigoFill: Color(0xFF22253E),
          actionPurpleBorder: Color(0xFF9575CD),
          actionPurpleFill: Color(0xFF2B2140),
          actionBlueGreyBorder: Color(0xFF90A4AE),
          actionBlueGreyFill: Color(0xFF1F2A30),
          actionGreenBorder: Color(0xFF66BB6A),
          actionGreenFill: Color(0xFF1E2A1F),
          actionOrangeBorder: Color(0xFFFFA726),
          actionOrangeFill: Color(0xFF3B2F1A),
        ),
        AppThemeStyles(
          body: const TextStyle(fontSize: 14, height: 1.35),
          bodySmall: const TextStyle(fontSize: 12, height: 1.30),
          caption: const TextStyle(fontSize: 11, height: 1.25),
          labelSmall: const TextStyle(fontSize: 10, height: 1.20, fontWeight: FontWeight.w600),
        ),
      ],
    );

    return MaterialApp(
      title: 'OS AI',
      theme: light,
      darkTheme: dark,
      themeMode: themeStore.mode,
      builder: (context, child) {
        // AppConfig is now provided from main.dart with loaded API keys
        return MultiProvider(
          providers: [
            Provider(create: (_) => BackendWsClient()),
            Provider(create: (_) => BackendRestClient()),
            Provider<ChatCache>(create: (_) => HiveChatCache()),
            ProxyProvider3<AppConfig, BackendWsClient, BackendRestClient, ChatRepository>(
              update: (_, cfg, ws, rest, prev) {
                // push config into clients
                rest.baseUrl = cfg.restBase();
                rest.bearer = cfg.token;
                final repo = prev ?? ChatRepositoryImpl(ws, rest);
                if (repo is ChatRepositoryImpl) {
                  repo.updateWsUriProvider(cfg.wsUri);
                }
                return repo;
              },
            ),
            ProxyProvider2<ChatRepository, ChatCache, ChatStore>(
              update: (_, repo, cache, prev) => prev ?? ChatStore(repo, cache: cache),
            ),
          ],
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: ColoredBox(
        color: Colors.transparent,
        child: const ChatScreen(),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
