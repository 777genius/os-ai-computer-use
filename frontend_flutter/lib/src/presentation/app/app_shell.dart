import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend_flutter/src/features/chat/presentation/screen/chat_screen.dart';
import 'package:frontend_flutter/src/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:frontend_flutter/src/features/chat/domain/repositories/chat_repository.dart';
import 'package:frontend_flutter/src/app/services/secure_storage_service.dart';
import 'package:frontend_flutter/src/presentation/settings/first_run_dialog.dart';
import 'package:get_it/get_it.dart';

/// Shell widget that sits inside MaterialApp tree.
/// Handles first-run dialog and ChatRepository disposal.
/// Must be a descendant of MaterialApp to have access to MaterialLocalizations.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  void initState() {
    super.initState();
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
    return const ChatScreen();
  }
}
