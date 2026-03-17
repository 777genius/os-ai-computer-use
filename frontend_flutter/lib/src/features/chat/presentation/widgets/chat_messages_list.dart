import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// removed duplicate provider import
import 'package:frontend_flutter/src/features/chat/presentation/widgets/attachment_bubble.dart';
import 'package:frontend_flutter/src/features/chat/presentation/widgets/lightbox_viewer.dart';
import 'package:frontend_flutter/src/features/chat/presentation/widgets/album_bubble.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';
import 'package:frontend_flutter/src/features/chat/application/stores/chat_store.dart';
import 'package:frontend_flutter/src/presentation/theme/app_theme.dart';

class ChatMessagesList extends StatefulWidget {
  const ChatMessagesList({super.key});

  @override
  State<ChatMessagesList> createState() => _ChatMessagesListState();
}

class _ChatMessagesListState extends State<ChatMessagesList> {
  final ScrollController _ctrl = ScrollController();
  bool _atBottom = true;
  int _lastLen = 0;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onScroll);
    _ctrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_ctrl.hasClients) return;
    final pos = _ctrl.position;
    final bool atBottomNow = pos.pixels >= (pos.maxScrollExtent - 24);
    _atBottom = atBottomNow;
  }

  void _scrollToBottom() {
    if (!_ctrl.hasClients) return;
    final target = _ctrl.position.maxScrollExtent;
    _ctrl.animateTo(target, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        final store = context.read<ChatStore?>();
        final len = store?.messages.length ?? 0;

        // автопрокрутка только если пользователь в самом низу и пришли новые сообщения
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_atBottom && _lastLen != len) {
            _scrollToBottom();
          }
          _lastLen = len;
        });

        // Group consecutive action messages for compact display
        final groups = _groupMessages(store!.messages);

        return ListView.builder(
          controller: _ctrl,
          padding: const EdgeInsets.all(12),
          itemCount: groups.length,
          itemBuilder: (_, i) {
            final group = groups[i];
            // Peek at next group to attach usage badge to current message
            final nextUsage = (i + 1 < groups.length && groups[i + 1].length == 1 && groups[i + 1].first.kind == 'usage')
                ? groups[i + 1].first
                : null;

            if (group.length > 1) {
              return _withUsageBadge(_ActionGroup(actions: group), nextUsage);
            }
            final m = group.first;
            if (m.kind == 'attachment_album') {
              final list = (m.meta?['items'] as List?)?.cast<Map>() ?? const [];
              final items = list.map((e) => e.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''))).toList();
              return AlbumBubble(items: items, isUser: m.role == 'user');
            }
            if (m.kind == 'attachment') {
              final name = (m.meta?['name'] as String?) ?? (m.text ?? 'file');
              final fileId = (m.meta?['fileId'] as String?) ?? '';
              final preview = (m.meta?['previewBase64'] as String?);
              return AttachmentBubble(name: name, fileId: fileId, isUser: m.role == 'user', previewBase64: preview);
            }
            if (m.kind == 'screenshot' && m.imageBase64 != null && m.imageBase64!.isNotEmpty) {
              final screenshot = GestureDetector(
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => LightboxViewer(base64Images: [m.imageBase64!]),
                  ));
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 50,
                    height: 50,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: Image.memory(
                        const Base64Decoder().convert(m.imageBase64!),
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                ),
              );
              return _withUsageBadge(
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: screenshot,
                ),
                nextUsage,
              );
            }
            if (m.kind == 'usage') {
              // Skip — already attached as badge to previous message
              if (i > 0) {
                final prevGroup = groups[i - 1];
                final prevKind = prevGroup.length == 1 ? prevGroup.first.kind : 'action_group';
                if (prevKind != 'usage') {
                  return const SizedBox.shrink();
                }
              }
              // Orphan usage (no previous message) — show standalone
              return Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: _UsageBadge(meta: m.meta ?? const {}, useInfoColor: true),
                ),
              );
            }
            if (m.kind == 'action') {
              final meta = (m.meta ?? const {});
              final inner = (meta['meta'] is Map) ? (meta['meta'] as Map) : const {};
              final actionName = (inner['action'] as String?) ?? (meta['name'] as String? ?? '');
              // Skip screenshot actions — the screenshot image follows right after
              if (actionName.toLowerCase() == 'screenshot') {
                return const SizedBox.shrink();
              }
              // Skip tool_result confirmations (e.g. {"text": "ok"})
              if (actionName.toLowerCase() == 'tool_result' || actionName.isEmpty) {
                return const SizedBox.shrink();
              }
              final status = (m.meta?['status'] as String? ?? '').toLowerCase();
              final badge = _actionBadgeFor(context, actionName);
              final Color border = badge.$2;
              final Color fill = badge.$3;
              final IconData icon = badge.$1;
              return Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16, color: border),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                        decoration: BoxDecoration(
                          color: border.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: border.withValues(alpha: 0.4)),
                        ),
                        child: Text(status.isEmpty ? 'start' : status, style: Theme.of(context).textTheme.labelSmall),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          m.text ?? '',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (m.kind == 'thought') {
              final isThinking = (m.meta?['thinking'] as bool?) == true;
              final bubble = Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                decoration: BoxDecoration(
                  color: context.themeColors.assistantBubbleBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.themeColors.surfaceBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.psychology, size: 16, color: context.themeColors.assistantBubbleFg),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          m.text ?? '',
                          softWrap: true,
                          style: context.theme.style((t) => t.bodySmall, (c) => c.assistantBubbleFg),
                        ),
                      ),
                      if (isThinking) ...[
                        const SizedBox(width: 8),
                        SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: context.themeColors.assistantBubbleFg)),
                      ]
                    ],
                  ),
                );
              if (isThinking || m.text == null || m.text!.isEmpty) return _withUsageBadge(bubble, nextUsage);
              return _withUsageBadge(bubble, nextUsage, copyText: m.text);
            }
            final bubble = _MessageBubble(role: m.role, text: m.text ?? '', ts: m.ts);
            final align = m.role == 'user' ? Alignment.centerRight : Alignment.centerLeft;
            if ((m.text ?? '').isEmpty) return _withUsageBadge(bubble, nextUsage, alignment: align);
            return _withUsageBadge(bubble, nextUsage, copyText: m.text, alignment: align);
          },
        );
      },
    );
  }
}

/// Wraps a message widget with usage $ badge and optional copy button in top-right corner.
class _MessageOverlay extends StatefulWidget {
  final Widget child;
  final dynamic usageMsg;
  final String? copyText;
  final Alignment alignment;
  const _MessageOverlay({required this.child, this.usageMsg, this.copyText, this.alignment = Alignment.centerLeft});

  @override
  State<_MessageOverlay> createState() => _MessageOverlayState();
}

class _MessageOverlayState extends State<_MessageOverlay> {
  bool _hovered = false;
  bool _copied = false;

  void _copy() {
    if (widget.copyText == null) return;
    Clipboard.setData(ClipboardData(text: widget.copyText!));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasUsage = widget.usageMsg != null;
    final hasCopy = widget.copyText != null && widget.copyText!.isNotEmpty;
    if (!hasUsage && !hasCopy) {
      return Align(alignment: widget.alignment, child: widget.child);
    }

    final showButtons = _hovered && (hasUsage || hasCopy);

    return Align(
      alignment: widget.alignment,
      child: MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          if (showButtons)
            // Use LayoutBuilder to find child's actual rendered bounds
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        right: -12,
                        top: 2,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasUsage)
                              _UsageBadge(meta: widget.usageMsg.meta ?? const {}, useInfoColor: true),
                            if (_hovered && hasCopy) ...[
                              if (hasUsage) const SizedBox(height: 4),
                              GestureDetector(
                                onTap: _copy,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Icon(
                                    _copied ? Icons.check : Icons.copy,
                                    size: 13,
                                    color: _copied
                                        ? Colors.green
                                        : Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
      ),
    );
  }
}

Widget _withUsageBadge(Widget child, dynamic usageMsg, {String? copyText, Alignment alignment = Alignment.centerLeft}) {
  if (usageMsg == null && (copyText == null || copyText.isEmpty)) {
    return Align(alignment: alignment, child: child);
  }
  return _MessageOverlay(usageMsg: usageMsg, copyText: copyText, alignment: alignment, child: child);
}

/// Groups consecutive 'action' messages together.
/// Non-action messages stay as single-element groups.
List<List<dynamic>> _groupMessages(List messages) {
  final groups = <List<dynamic>>[];
  List<dynamic>? currentActions;
  for (final m in messages) {
    if (m.kind == 'action') {
      // Skip screenshot actions from grouping — image follows right after
      final meta = (m.meta ?? const {});
      final inner = (meta['meta'] is Map) ? (meta['meta'] as Map) : const {};
      final actionName = ((inner['action'] as String?) ?? '').toLowerCase();
      if (actionName == 'screenshot') continue;
      // Skip tool_result confirmations
      final metaName = ((meta['name'] as String?) ?? '').toLowerCase();
      if (actionName == 'tool_result' || metaName == 'tool_result' || actionName.isEmpty) continue;

      currentActions ??= [];
      currentActions.add(m);
    } else {
      if (currentActions != null) {
        groups.add(currentActions);
        currentActions = null;
      }
      groups.add([m]);
    }
  }
  if (currentActions != null) groups.add(currentActions);
  return groups;
}

class _ActionGroup extends StatefulWidget {
  final List actions;
  const _ActionGroup({required this.actions});

  @override
  State<_ActionGroup> createState() => _ActionGroupState();
}

class _ActionGroupState extends State<_ActionGroup> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final count = widget.actions.length;
    final colorScheme = Theme.of(context).colorScheme;
    final dominantAction = _dominantActionName();
    final badge = _actionBadgeFor(context, dominantAction);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: badge.$3,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: badge.$2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header — always visible
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badge.$1, size: 16, color: badge.$2),
                    const SizedBox(width: 6),
                    Text(
                      '$count actions',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Action type summary (e.g. "3× click, 2× drag")
                    Flexible(
                      child: Text(
                        _buildSummary(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            // Expanded list of actions
            if (_expanded)
              Padding(
                padding: const EdgeInsets.only(left: 10, right: 10, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 8, thickness: 0.5),
                    for (var j = 0; j < widget.actions.length; j++)
                      _ActionRow(index: j + 1, message: widget.actions[j]),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _buildSummary() {
    final counts = <String, int>{};
    for (final m in widget.actions) {
      final meta = (m.meta ?? const {});
      final inner = (meta['meta'] is Map) ? (meta['meta'] as Map) : const {};
      final action = (inner['action'] as String?) ?? '';
      final label = _shortLabel(action);
      counts[label] = (counts[label] ?? 0) + 1;
    }
    return counts.entries.map((e) => '${e.value}× ${e.key}').join(', ');
  }

  String _dominantActionName() {
    final counts = <String, int>{};
    for (final m in widget.actions) {
      final meta = (m.meta ?? const {});
      final inner = (meta['meta'] is Map) ? (meta['meta'] as Map) : const {};
      final action = ((inner['action'] as String?) ?? '').toLowerCase();
      if (action.isNotEmpty) {
        counts[action] = (counts[action] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return '';
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  String _shortLabel(String action) {
    switch (action.toLowerCase()) {
      case 'left_click': return 'click';
      case 'double_click': return 'dblclick';
      case 'right_click': return 'rclick';
      case 'left_click_drag': return 'drag';
      case 'left_mouse_down': return 'mousedown';
      case 'left_mouse_up': return 'mouseup';
      case 'mouse_move': return 'move';
      case 'type': return 'type';
      case 'key': case 'hold_key': return 'key';
      case 'scroll': return 'scroll';
      case 'screenshot': return 'screenshot';
      default: return action;
    }
  }
}

/// Single action row inside the expanded group.
/// Shows clean label parsed from meta. Tappable to see full details.
class _ActionRow extends StatelessWidget {
  final int index;
  final dynamic message;
  const _ActionRow({required this.index, required this.message});

  @override
  Widget build(BuildContext context) {
    final meta = (message.meta ?? const {}) as Map;
    final inner = (meta['meta'] is Map) ? (meta['meta'] as Map) : const {};
    final action = ((inner['action'] as String?) ?? '').toLowerCase();
    final label = _formatClean(action, inner);
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () => _showDetails(context, inner),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        child: Row(
          children: [
            Text(
              '$index.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 6),
            _iconWidget(action, colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Icon(Icons.chevron_right, size: 14, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }

  static Widget _iconWidget(String action, Color color) {
    const s = 14.0;
    if (action == 'left_click' || action == 'middle_click') return Icon(Icons.ads_click, size: s, color: color);
    if (action == 'double_click' || action == 'triple_click') return Icon(Icons.touch_app, size: s, color: color);
    if (action == 'right_click') return Icon(Icons.more_horiz, size: s, color: color);
    if (action == 'left_mouse_down' || action == 'left_mouse_up') return Icon(Icons.ads_click, size: s, color: color);
    if (action.contains('drag')) return Icon(Icons.open_with, size: s, color: color);
    if (action == 'mouse_move') return Icon(Icons.near_me, size: s, color: color);
    if (action == 'type') return Icon(Icons.keyboard, size: s, color: color);
    if (action == 'key' || action == 'hold_key') return Icon(Icons.keyboard_command_key, size: s, color: color);
    if (action == 'scroll') return Icon(Icons.swap_vert, size: s, color: color);
    if (action == 'screenshot') return Icon(Icons.screenshot_monitor, size: s, color: color);
    return Icon(Icons.build, size: s, color: color);
  }

  /// Human-readable label parsed from meta (not from m.text).
  static String _formatClean(String action, Map inner) {
    if (action == 'screenshot') return 'Screenshot';
    if (action == 'mouse_move') {
      return 'Move → ${_coord(inner['coordinate'])}';
    }
    if (action == 'left_click') return 'Click ${_coord(inner['coordinate'])}';
    if (action == 'double_click') return 'Double click ${_coord(inner['coordinate'])}';
    if (action == 'triple_click') return 'Triple click ${_coord(inner['coordinate'])}';
    if (action == 'right_click') return 'Right click ${_coord(inner['coordinate'])}';
    if (action == 'left_mouse_down') return 'Mouse down ${_coord(inner['coordinate'])}';
    if (action == 'left_mouse_up') return 'Mouse up ${_coord(inner['coordinate'])}';
    if (action == 'left_click_drag') {
      return 'Drag ${_coord(inner['start_coordinate'] ?? inner['start'])} → ${_coord(inner['end_coordinate'] ?? inner['end'])}';
    }
    if (action == 'type') {
      final t = (inner['text'] as String?) ?? '';
      return 'Type "${t.length > 40 ? '${t.substring(0, 40)}...' : t}"';
    }
    if (action == 'key' || action == 'hold_key') {
      return 'Key ${(inner['key'] as String?) ?? (inner['text'] as String?) ?? ''}';
    }
    if (action == 'scroll') {
      return 'Scroll ${(inner['scroll_direction'] as String?) ?? 'down'} ×${inner['scroll_amount'] ?? 1}';
    }
    if (action == 'wait') return 'Wait';
    return action.replaceAll('_', ' ');
  }

  static String _coord(dynamic c) {
    if (c is List && c.length >= 2) return '(${c[0]}, ${c[1]})';
    return '';
  }

  void _showDetails(BuildContext context, Map details) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Action #$index', style: const TextStyle(fontSize: 16)),
        content: SingleChildScrollView(
          child: SelectableText(
            const JsonEncoder.withIndent('  ').convert(details),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(
                text: const JsonEncoder.withIndent('  ').convert(details),
              ));
              Navigator.pop(context);
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}



class _MessageBubble extends StatelessWidget {
  final String role;
  final String text;
  final DateTime ts;
  const _MessageBubble({required this.role, required this.text, required this.ts});

  bool get isUser => role == 'user';

  @override
  Widget build(BuildContext context) {
    final timeStr = '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
    final timeColor = isUser
        ? Colors.white.withValues(alpha: 0.6)
        : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5);
    final textStyle = isUser
        ? context.theme.style((t) => t.body, (c) => c.userBubbleFg)
        : context.theme.style((t) => t.body, (c) => c.assistantBubbleFg);
    final timeStyle = TextStyle(fontSize: 10, color: timeColor);

    const timePadding = '              '; // reserve space for "HH:MM"

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 5),
      decoration: BoxDecoration(
        color: isUser ? context.themeColors.userBubbleBg : context.themeColors.assistantBubbleBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: text, style: textStyle),
                TextSpan(
                  text: timePadding,
                  style: textStyle.copyWith(color: const Color(0x00000000)),
                ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Text(timeStr, style: timeStyle),
          ),
        ],
      ),
    );
  }
}

// Returns (icon, borderColor, fillColor)
(IconData, Color, Color) _actionBadgeFor(BuildContext context, String name) {
  final n = name.toLowerCase();
  if (n == 'screenshot') {
    return (Icons.screenshot_monitor, context.themeColors.actionTealBorder, context.themeColors.actionTealFill);
  }
  if (n == 'mouse_move') {
    return (Icons.near_me, context.themeColors.actionIndigoBorder, context.themeColors.actionIndigoFill);
  }
  if (n == 'left_click' || n == 'double_click' || n == 'triple_click' || n == 'right_click' || n == 'middle_click') {
    return (Icons.ads_click, context.themeColors.actionPurpleBorder, context.themeColors.actionPurpleFill);
  }
  if (n == 'left_mouse_down' || n == 'left_mouse_up') {
    return (Icons.ads_click, context.themeColors.actionPurpleBorder, context.themeColors.actionPurpleFill);
  }
  if (n == 'left_click_drag') {
    return (Icons.open_with, context.themeColors.actionPurpleBorder, context.themeColors.actionPurpleFill);
  }
  if (n == 'type') {
    return (Icons.keyboard, context.themeColors.actionBlueGreyBorder, context.themeColors.actionBlueGreyFill);
  }
  if (n == 'key' || n == 'hold_key') {
    return (Icons.keyboard_command_key, context.themeColors.actionBlueGreyBorder, context.themeColors.actionBlueGreyFill);
  }
  if (n == 'scroll') {
    return (Icons.swap_vert, context.themeColors.actionGreenBorder, context.themeColors.actionGreenFill);
  }
  if (n == 'wait') {
    return (Icons.hourglass_empty, context.themeColors.actionOrangeBorder, context.themeColors.actionOrangeFill);
  }
  return (Icons.build, context.themeColors.actionPurpleBorder, context.themeColors.actionPurpleFill);
}

class _UsageBadge extends StatelessWidget {
  final Map<String, dynamic> meta;
  final bool useInfoColor;
  const _UsageBadge({required this.meta, this.useInfoColor = false});

  @override
  Widget build(BuildContext context) {
    final inTok = meta['inputTokens'] ?? 0;
    final outTok = meta['outputTokens'] ?? 0;
    final inUsd = (meta['inputUsd'] as num?)?.toDouble() ?? 0.0;
    final outUsd = (meta['outputUsd'] as num?)?.toDouble() ?? 0.0;
    final stepUsd = (meta['totalUsd'] as num?)?.toDouble() ?? (inUsd + outUsd);
    final stepTok = (inTok is int ? inTok : 0) + (outTok is int ? outTok : 0);

    // Accumulated totals from ChatStore
    final store = context.read<ChatStore?>();
    final accumTok = (store?.totalInputTokens ?? 0) + (store?.totalOutputTokens ?? 0);
    final accumUsd = store?.totalUsd ?? 0.0;

    final borderColor = useInfoColor
        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
        : context.themeColors.usageBorder.withValues(alpha: 0.4);
    final fillColor = useInfoColor
        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
        : context.themeColors.usageFill.withValues(alpha: 0.6);
    final iconColor = useInfoColor
        ? Theme.of(context).colorScheme.primary
        : context.themeColors.usageBorder;

    return Tooltip(
      richMessage: TextSpan(
        style: const TextStyle(fontSize: 12, height: 1.5),
        children: [
          const TextSpan(text: 'Input:  ', style: TextStyle(fontWeight: FontWeight.w600)),
          TextSpan(text: '$inTok tokens  \$${inUsd.toStringAsFixed(6)}\n'),
          const TextSpan(text: 'Output: ', style: TextStyle(fontWeight: FontWeight.w600)),
          TextSpan(text: '$outTok tokens  \$${outUsd.toStringAsFixed(6)}\n'),
          const TextSpan(text: 'Step:   ', style: TextStyle(fontWeight: FontWeight.w600)),
          TextSpan(text: '$stepTok tokens  \$${stepUsd.toStringAsFixed(6)}\n'),
          const TextSpan(text: 'Total:  ', style: TextStyle(fontWeight: FontWeight.w600)),
          TextSpan(text: '$accumTok tokens  \$${accumUsd.toStringAsFixed(4)}'),
        ],
      ),
      waitDuration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Icon(
          Icons.attach_money,
          size: 13,
          color: iconColor,
        ),
      ),
    );
  }
}


