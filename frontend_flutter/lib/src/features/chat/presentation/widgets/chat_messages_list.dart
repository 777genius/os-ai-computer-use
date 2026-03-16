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

        return ListView.builder(
          controller: _ctrl,
          padding: const EdgeInsets.all(12),
          itemCount: len,
          itemBuilder: (_, i) {
            final m = store!.messages[i];
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
              return Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: context.themeColors.surfaceBorder),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Screenshot (${m.ts.toIso8601String().substring(11, 19)})',
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => LightboxViewer(base64Images: [m.imageBase64!]),
                              ));
                            },
                            child: _ZoomableBase64Image(base64Data: m.imageBase64!),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              );
            }
            if (m.kind == 'usage') {
              return Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  decoration: BoxDecoration(
                    color: context.themeColors.usageFill,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.themeColors.usageBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('📈'),
                      const SizedBox(width: 6),
                      Text(
                        m.text ?? '',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              );
            }
            if (m.kind == 'action') {
              final meta = (m.meta ?? const {});
              final inner = (meta['meta'] is Map) ? (meta['meta'] as Map) : const {};
              final actionName = (inner['action'] as String?) ?? (meta['name'] as String? ?? '');
              final status = (m.meta?['status'] as String? ?? '').toLowerCase();
              final badge = _actionBadgeFor(context, actionName);
              final Color border = badge.$2;
              final Color fill = badge.$3;
              final String icon = badge.$1;
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
                      Text(icon),
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
              final bubble = Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  decoration: BoxDecoration(
                    color: context.themeColors.assistantBubbleBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.themeColors.surfaceBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🧠'),
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
                ),
              );
              if (isThinking || m.text == null || m.text!.isEmpty) return bubble;
              return _CopyableHover(text: m.text!, child: bubble);
            }
            final bubble = _MessageBubble(role: m.role, text: m.text ?? '');
            if ((m.text ?? '').isEmpty) return bubble;
            return _CopyableHover(text: m.text!, child: bubble);
          },
        );
      },
    );
  }
}

class _CopyableHover extends StatefulWidget {
  final String text;
  final Widget child;
  const _CopyableHover({required this.text, required this.child});

  @override
  State<_CopyableHover> createState() => _CopyableHoverState();
}

class _CopyableHoverState extends State<_CopyableHover> {
  bool _hovered = false;
  bool _copied = false;

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.text));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          if (_hovered)
            Positioned(
              top: 2,
              right: 2,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _copy,
                  borderRadius: BorderRadius.circular(6),
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
                      size: 14,
                      color: _copied
                          ? Colors.green
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String role;
  final String text;
  const _MessageBubble({required this.role, required this.text});

  @override
  Widget build(BuildContext context) {
    final isUser = role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: isUser ? context.themeColors.userBubbleBg : context.themeColors.assistantBubbleBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: isUser
              ? context.theme.style((t) => t.body, (c) => c.userBubbleFg)
              : context.theme.style((t) => t.body, (c) => c.assistantBubbleFg),
        ),
      ),
    );
  }
}

// Returns (icon, borderColor, fillColor)
(String, Color, Color) _actionBadgeFor(BuildContext context, String name) {
  final n = name.toLowerCase();
  if (n == 'screenshot') {
    return ('📸', context.themeColors.actionTealBorder, context.themeColors.actionTealFill);
  }
  if (n == 'mouse_move') {
    return ('🖱️', context.themeColors.actionIndigoBorder, context.themeColors.actionIndigoFill);
  }
  if (n == 'left_click' || n == 'double_click' || n == 'triple_click' || n == 'right_click' || n == 'middle_click') {
    return ('🖱️', context.themeColors.actionPurpleBorder, context.themeColors.actionPurpleFill);
  }
  if (n == 'left_click_drag') {
    return ('🖱️', context.themeColors.actionPurpleBorder, context.themeColors.actionPurpleFill);
  }
  if (n == 'type') {
    return ('⌨️', context.themeColors.actionBlueGreyBorder, context.themeColors.actionBlueGreyFill);
  }
  if (n == 'key' || n == 'hold_key') {
    return ('⌨️', context.themeColors.actionBlueGreyBorder, context.themeColors.actionBlueGreyFill);
  }
  if (n == 'scroll') {
    return ('🌀', context.themeColors.actionGreenBorder, context.themeColors.actionGreenFill);
  }
  if (n == 'wait') {
    return ('⏱️', context.themeColors.actionOrangeBorder, context.themeColors.actionOrangeFill);
  }
  return ('🔧', context.themeColors.actionPurpleBorder, context.themeColors.actionPurpleFill);
}

class _ZoomableBase64Image extends StatefulWidget {
  final String base64Data;
  const _ZoomableBase64Image({required this.base64Data});

  @override
  State<_ZoomableBase64Image> createState() => _ZoomableBase64ImageState();
}

class _ZoomableBase64ImageState extends State<_ZoomableBase64Image> {
  bool zoomed = false;

  @override
  Widget build(BuildContext context) {
    final bytes = const Base64Decoder().convert(widget.base64Data);
    final img = Image.memory(bytes, gaplessPlayback: true);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: zoomed
                ? InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4,
                    child: img,
                  )
                : SizedBox(
                    width: 150,
                    height: 150,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: img,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => setState(() => zoomed = !zoomed),
            icon: Icon(zoomed ? Icons.zoom_out : Icons.zoom_in),
            label: Text(zoomed ? 'Zoom out' : 'Zoom in'),
          ),
        ),
      ],
    );
  }
}


