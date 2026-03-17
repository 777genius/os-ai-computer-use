import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';
import 'package:frontend_flutter/src/features/chat/application/stores/chat_store.dart';
import 'package:frontend_flutter/src/presentation/theme/app_theme.dart';

class ChatListSidebar extends StatelessWidget {
  final void Function()? onCreateChat;
  final void Function()? onOpenUsage;
  final void Function()? onChatTapped;
  final double? width;
  final bool showHeader;
  final bool showBorder;
  const ChatListSidebar({
    super.key,
    this.onCreateChat,
    this.onOpenUsage,
    this.onChatTapped,
    this.width,
    this.showHeader = true,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgAlpha = isDark ? 0.47 : 0.2;
    return Container(
      width: width ?? 280,
      decoration: showBorder
          ? BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: bgAlpha),
              border: Border(right: BorderSide(color: context.themeColors.surfaceBorder)),
            )
          : null,
      child: Column(
        children: [
          if (showHeader)
            Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Chats',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'New chat',
                  onPressed: onCreateChat,
                  icon: Icon(Icons.add, color: Theme.of(context).colorScheme.onSurface),
                ),
                IconButton(
                  tooltip: 'Usage',
                  onPressed: onOpenUsage,
                  icon: Icon(Icons.bar_chart_outlined, color: Theme.of(context).colorScheme.onSurface),
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
                    onTap: () {
                      store?.setActiveChat(s.id);
                      onChatTapped?.call();
                    },
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
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: widget.isActive ? FontWeight.w600 : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (s.lastMessageText ?? '').isEmpty ? '—' : s.lastMessageText!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '${s.totalInputTokens + s.totalOutputTokens} tok',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
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
                    icon: Icon(Icons.edit, size: 18, color: Theme.of(context).colorScheme.onSurface),
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
                    icon: Icon(Icons.delete_outline, size: 18, color: Theme.of(context).colorScheme.error),
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


