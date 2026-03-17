import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend_flutter/src/features/chat/application/stores/chat_store.dart';
import 'package:frontend_flutter/src/features/chat/presentation/widgets/chat_list_sidebar.dart';

/// Fullscreen chat list used in overlay (compact) mode.
/// Reuses [ChatListSidebar] — selecting a chat pops back to the chat screen.
class ChatListOverlayScreen extends StatelessWidget {
  const ChatListOverlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 36,
        titleSpacing: 0,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, size: 18),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
        title: Text(
          'Chats',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        actions: [
          IconButton(
            tooltip: 'New chat',
            onPressed: () {
              final s = context.read<ChatStore?>();
              s?.createNewChat();
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.add, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ChatListSidebar(
        width: double.infinity,
        showHeader: false,
        showBorder: false,
        onCreateChat: () {
          final s = context.read<ChatStore?>();
          s?.createNewChat();
          Navigator.of(context).pop();
        },
        onChatTapped: () => Navigator.of(context).pop(),
      ),
    );
  }
}
