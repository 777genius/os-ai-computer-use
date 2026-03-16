import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';

import 'package:frontend_flutter/src/features/chat/application/stores/chat_store.dart';
import 'package:frontend_flutter/src/features/chat/domain/entities/connection_status.dart';
import 'package:frontend_flutter/src/features/chat/domain/repositories/chat_repository.dart';
import 'package:frontend_flutter/src/features/chat/presentation/utils/image_compress.dart';
import 'package:frontend_flutter/src/features/chat/presentation/widgets/chat_input_composer.dart';
import 'package:frontend_flutter/src/features/chat/presentation/widgets/chat_list_sidebar.dart';
import 'package:frontend_flutter/src/features/chat/presentation/widgets/chat_messages_list.dart';
import 'package:frontend_flutter/src/features/chat/presentation/widgets/upload_overlay.dart';
import 'package:frontend_flutter/src/features/usage/presentation/usage_screen.dart';
import 'package:frontend_flutter/src/presentation/stores/theme_store.dart';
import 'package:frontend_flutter/src/presentation/theme/app_theme.dart';
import 'package:frontend_flutter/src/presentation/utils/drop_target.dart';
import 'package:frontend_flutter/src/presentation/overlay/window_mode_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final store = context.read<ChatStore?>();
      store?.init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final wms = context.read<WindowModeService>();

    return ListenableBuilder(
      listenable: wms,
      builder: (context, _) {
        final isOverlay = wms.isOverlay;
        return _buildScreen(context, isOverlay: isOverlay);
      },
    );
  }

  Widget _buildScreen(BuildContext context, {required bool isOverlay}) {
    final isMacOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgAlpha = isDark ? 0.7 : 0.3;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _buildAppBar(
        context,
        isOverlay: isOverlay,
        isMacOS: isMacOS,
        bgAlpha: bgAlpha,
      ),
      body: _buildBody(
        context,
        isOverlay: isOverlay,
        bgAlpha: bgAlpha,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context, {
    required bool isOverlay,
    required bool isMacOS,
    required double bgAlpha,
  }) {
    // In overlay mode: compact bar, no traffic light padding, expand button
    // In normal mode: full bar with sidebar padding and all actions
    final titleSpacing = isOverlay ? 12.0 : (isMacOS ? 78.0 : 16.0);
    final toolbarHeight = isOverlay ? 36.0 : (isMacOS ? 38.0 : kToolbarHeight);

    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: bgAlpha),
      surfaceTintColor: Colors.transparent,
      toolbarHeight: toolbarHeight,
      titleSpacing: titleSpacing,
      title: _AppBarTitle(isOverlay: isOverlay),
      actions: _buildActions(context, isOverlay: isOverlay),
    );
  }

  List<Widget> _buildActions(BuildContext context, {required bool isOverlay}) {
    final wms = context.read<WindowModeService>();

    if (isOverlay) {
      return [
        IconButton(
          tooltip: 'Minimize',
          onPressed: () => wms.minimizeWindow(),
          icon: const Icon(Icons.remove, size: 16),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        IconButton(
          tooltip: 'Expand (Cmd+Shift+O)',
          onPressed: () => wms.exitOverlay(),
          icon: const Icon(Icons.open_in_full, size: 16),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        const SizedBox(width: 8),
      ];
    }

    // Normal mode: all actions
    return [
      IconButton(
        tooltip: 'Compact overlay (Cmd+Shift+O)',
        onPressed: () => wms.enterOverlay(),
        icon: const Icon(Icons.picture_in_picture_alt, size: 20),
      ),
      IconButton(
        tooltip: 'Toggle theme',
        onPressed: () {
          final ts = context.read<ThemeStore?>();
          if (ts == null) return;
          ts.toggleUsing(context);
        },
        icon: const Icon(Icons.brightness_6),
      ),
      const SizedBox(width: 12),
      Observer(builder: (_) {
        final running = context.watch<ChatStore?>()?.running ?? false;
        return running
            ? const Padding(
                padding: EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : const SizedBox.shrink();
      }),
    ];
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isOverlay,
    required double bgAlpha,
  }) {
    final chatArea = Container(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: bgAlpha),
      child: UploadOverlay(
        child: _ChatDropArea(
          child: const Column(
            children: [
              Expanded(child: ChatMessagesList()),
              ChatInputComposer(),
            ],
          ),
        ),
      ),
    );

    // In overlay mode: no sidebar, just chat
    if (isOverlay) {
      return chatArea;
    }

    // Normal mode: sidebar + chat
    return Row(
      children: [
        ChatListSidebar(
          onCreateChat: () {
            final s = context.read<ChatStore?>();
            s?.createNewChat();
          },
          onOpenUsage: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const UsageScreen()),
            );
          },
        ),
        Expanded(child: chatArea),
      ],
    );
  }
}

/// AppBar title — adapts to overlay mode.
class _AppBarTitle extends StatelessWidget {
  final bool isOverlay;

  const _AppBarTitle({required this.isOverlay});

  @override
  Widget build(BuildContext context) {
    return Observer(builder: (_) {
      final storeWatch = context.watch<ChatStore?>();
      final u = storeWatch?.usage;
      final totalUsd = storeWatch?.totalUsd ?? 0.0;
      final tin = storeWatch?.totalInputTokens ?? 0;
      final tout = storeWatch?.totalOutputTokens ?? 0;
      final conn = storeWatch?.connection ?? ConnectionStatus.connecting;

      final statusDot = _StatusDot(connection: conn);

      // In overlay mode: just title + status, no usage line
      if (isOverlay) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            statusDot,
            const SizedBox(width: 6),
            Text(
              'OS AI',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            // Show running indicator inline in overlay
            Observer(builder: (_) {
              final running = context.watch<ChatStore?>()?.running ?? false;
              if (!running) return const SizedBox.shrink();
              return const Padding(
                padding: EdgeInsets.only(left: 8),
                child: SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }),
          ],
        );
      }

      // Normal mode: full title with usage
      final usageLine = (u == null || (tin + tout) == 0)
          ? null
          : 'in=${u.inputTokens} out=${u.outputTokens}'
              '  \u03A3tokens=${tin + tout}'
              '  \$${u.totalUsd.toStringAsFixed(4)}'
              ' (\u03A3 \$${totalUsd.toStringAsFixed(4)})';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'OS AI',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: switch (conn) {
                  ConnectionStatus.connected => 'Connected',
                  ConnectionStatus.connecting => 'Connecting...',
                  ConnectionStatus.disconnected => 'Disconnected',
                  ConnectionStatus.offline => 'Offline',
                  ConnectionStatus.error => 'Connection error',
                },
                child: statusDot,
              ),
            ],
          ),
          if (usageLine != null)
            Text(
              usageLine,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
        ],
      );
    });
  }
}

/// Connection status dot — reused in both modes.
class _StatusDot extends StatelessWidget {
  final ConnectionStatus connection;

  const _StatusDot({required this.connection});

  @override
  Widget build(BuildContext context) {
    switch (connection) {
      case ConnectionStatus.connected:
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: context.themeColors.actionGreenBorder,
            shape: BoxShape.circle,
          ),
        );
      case ConnectionStatus.offline:
      case ConnectionStatus.error:
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.error,
            shape: BoxShape.circle,
          ),
        );
      case ConnectionStatus.disconnected:
      case ConnectionStatus.connecting:
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
    }
  }
}

class _ChatDropArea extends StatefulWidget {
  final Widget child;
  const _ChatDropArea({required this.child});

  @override
  State<_ChatDropArea> createState() => _ChatDropAreaState();
}

class _ChatDropAreaState extends State<_ChatDropArea> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final overlayColor = Theme.of(context).colorScheme.primary.withValues(alpha: 0.08);
    return Stack(
      children: [
        DropTarget(
          onDragEntered: (_) => setState(() => _dragging = true),
          onDragExited: (_) => setState(() => _dragging = false),
          onDragDone: (details) async {
            setState(() => _dragging = false);
            final repo = context.read<ChatRepository?>();
            if (repo == null) return;
            final store = context.read<UploadStore?>();
            // Limits
            const maxBytes = 25 * 1024 * 1024; // 25MB
            const allowed = {"png", "jpg", "jpeg", "webp"};
            for (final x in details.files) {
              try {
                // Prefer native file path when available
                if (x.path != null && x.path!.isNotEmpty && await File(x.path!).exists()) {
                  final f = File(x.path!);
                  final name = f.uri.pathSegments.last;
                  final ext = name.split('.').length > 1 ? name.split('.').last.toLowerCase() : '';
                  if (!allowed.contains(ext)) { store?.fail(name, 'unsupported type'); continue; }
                  final stat = await f.stat();
                  if (stat.size > maxBytes) { store?.fail(name, 'too large'); continue; }
                  final bytes = await f.readAsBytes();
                  final cmp = await compressIfNeeded(Uint8List.fromList(bytes));
                  final out = cmp.bytes;
                  final previewB64 = await makePreviewBase64(out);
                  var canceled = false;
                  VoidCallback? cancelNetwork;
                  store?.start(name, out.length, onCancel: () { canceled = true; cancelNetwork?.call(); }, previewBytes: out.length > 2 * 1024 * 1024 ? null : out);
                  await repo.uploadFile(
                    name,
                    out,
                    mime: cmp.mime,
                    onProgress: (s, t){ if (!canceled) store?.progress(name, s, t); },
                    onCreateCancel: (fn){ cancelNetwork = fn; },
                    previewBase64: previewB64,
                  );
                  store?.complete(name);
                } else {
                  final data = await x.readAsBytes();
                  final cmp2 = await compressIfNeeded(Uint8List.fromList(data));
                  final name = x.name.isNotEmpty ? x.name : 'file.bin';
                  final ext = name.split('.').length > 1 ? name.split('.').last.toLowerCase() : '';
                  if (!allowed.contains(ext)) { store?.fail(name, 'unsupported type'); continue; }
                  if (cmp2.bytes.length > maxBytes) { store?.fail(name, 'too large'); continue; }
                  var canceled = false;
                  VoidCallback? cancelNetwork;
                  final previewB64 = await makePreviewBase64(cmp2.bytes);
                  store?.start(name, cmp2.bytes.length, onCancel: () { canceled = true; cancelNetwork?.call(); }, previewBytes: cmp2.bytes.length > 2 * 1024 * 1024 ? null : cmp2.bytes);
                  await repo.uploadFile(
                    name,
                    cmp2.bytes,
                    mime: cmp2.mime,
                    onProgress: (s, t){ if (!canceled) store?.progress(name, s, t); },
                    onCreateCancel: (fn){ cancelNetwork = fn; },
                    previewBase64: previewB64,
                  );
                  store?.complete(name);
                }
              } catch (_) {}
            }
          },
          child: widget.child,
        ),
        if (_dragging)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: overlayColor,
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'Drop files to attach',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
