import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';
import 'package:frontend_flutter/src/features/chat/application/stores/chat_store.dart';
import 'package:frontend_flutter/src/presentation/theme/app_theme.dart';

class ChatListSidebar extends StatelessWidget {
  final void Function()? onCreateChat;
  final void Function()? onOpenUsage;
  const ChatListSidebar({super.key, this.onCreateChat, this.onOpenUsage});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
        border: Border(right: BorderSide(color: context.themeColors.surfaceBorder)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Chats',
                    style: context.theme.style((t) => t.body, (c) => c.assistantBubbleFg),
                  ),
                ),
                IconButton(
                  tooltip: 'New chat',
                  onPressed: onCreateChat,
                  icon: const Icon(Icons.add),
                ),
                IconButton(
                  tooltip: 'Usage',
                  onPressed: onOpenUsage,
                  icon: const Icon(Icons.bar_chart_outlined),
                ),
              ],
            ),
          ),
          Expanded(
            child: Observer(builder: (_) {
              final store = context.read<ChatStore?>();
              final sessions = store?.sessions ?? const [];
              final active = store?.activeChatId;
              return ListView.separated(
                itemCount: sessions.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: context.themeColors.surfaceBorder),
                itemBuilder: (_, i) {
                  final s = sessions[i];
                  final isActive = s.id == active;
                  return _ChatListItem(
                    session: s,
                    isActive: isActive,
                    onTap: () => store?.setActiveChat(s.id),
                    onRename: (newTitle) => store?.renameChat(s.id, newTitle),
                    onDelete: () => store?.removeChat(s.id),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _ChatListItem extends StatefulWidget {
  final dynamic session;
  final bool isActive;
  final VoidCallback onTap;
  final void Function(String) onRename;
  final VoidCallback onDelete;

  const _ChatListItem({
    required this.session,
    required this.isActive,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  State<_ChatListItem> createState() => _ChatListItemState();
}

class _ChatListItemState extends State<_ChatListItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: widget.isActive
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.theme.style((t) => t.body, (c) => c.assistantBubbleFg),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (s.lastMessageText ?? '').isEmpty ? '—' : s.lastMessageText!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.theme.style((t) => t.caption, (c) => c.assistantBubbleFg),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (!_isHovered) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${s.totalUsd.toStringAsFixed(4)}',
                        style: context.theme.style((t) => t.caption, (c) => c.assistantBubbleFg),
                      ),
                      Text(
                        '${s.totalInputTokens + s.totalOutputTokens} tok',
                        style: context.theme.style((t) => t.caption, (c) => c.assistantBubbleFg),
                      ),
                    ],
                  ),
                ],
                if (_isHovered) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Rename',
                    visualDensity: VisualDensity.compact,
                    onPressed: () async {
                      final controller = TextEditingController(text: s.title);
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) {
                          return AlertDialog(
                            title: const Text('Rename chat'),
                            content: TextField(controller: controller, autofocus: true),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Save')),
                            ],
                          );
                        },
                      );
                      if (ok == true) {
                        final title = controller.text.trim();
                        if (title.isNotEmpty) {
                          widget.onRename(title);
                        }
                      }
                    },
                    icon: const Icon(Icons.edit, size: 18),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    visualDensity: VisualDensity.compact,
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) {
                          return AlertDialog(
                            title: const Text('Delete chat?'),
                            content: const Text('This cannot be undone.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
                            ],
                          );
                        },
                      );
                      if (ok == true) {
                        widget.onDelete();
                      }
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}


