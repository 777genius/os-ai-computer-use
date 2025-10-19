import 'package:flutter/material.dart';
import 'package:frontend_flutter/src/features/chat/presentation/widgets/chat_messages_list.dart';
import 'package:frontend_flutter/src/features/chat/presentation/widgets/chat_input_composer.dart';
import 'package:frontend_flutter/src/features/chat/presentation/widgets/chat_list_sidebar.dart';
import 'package:provider/provider.dart';
import 'package:frontend_flutter/src/presentation/utils/drop_target.dart';
import 'package:frontend_flutter/src/features/chat/presentation/widgets/upload_overlay.dart';
import 'package:frontend_flutter/src/features/chat/presentation/utils/image_compress.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:frontend_flutter/src/features/chat/domain/repositories/chat_repository.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frontend_flutter/src/features/chat/application/stores/chat_store.dart';
import 'package:frontend_flutter/src/presentation/stores/theme_store.dart';
import 'package:frontend_flutter/src/presentation/theme/app_theme.dart';
import 'package:frontend_flutter/src/features/chat/domain/entities/connection_status.dart';
import 'package:frontend_flutter/src/features/usage/presentation/usage_screen.dart';

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
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
        surfaceTintColor: Colors.transparent,
        title: Observer(builder: (_) {
          final storeWatch = context.watch<ChatStore?>();
          final u = storeWatch?.usage;
          final totalUsd = storeWatch?.totalUsd ?? 0.0;
          final tin = storeWatch?.totalInputTokens ?? 0;
          final tout = storeWatch?.totalOutputTokens ?? 0;
          final conn = storeWatch?.connection ?? ConnectionStatus.connecting;
          // Small status indicator: green dot (connected), red dot (offline/error) or loader (connecting/disconnected)
          Widget statusIndicator() {
            switch (conn) {
              case ConnectionStatus.connected:
                return Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: context.themeColors.actionGreenBorder, shape: BoxShape.circle),
                );
              case ConnectionStatus.offline:
              case ConnectionStatus.error:
                return Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.error, shape: BoxShape.circle),
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
          final usageLine = (u == null || (tin + tout) == 0)
              ? null
              : 'in=' + u.inputTokens.toString() + ' out=' + u.outputTokens.toString() +
                  '  Σtokens=' + (tin + tout).toString() +
                  '  \$' + u.totalUsd.toStringAsFixed(4) +
                  ' (Σ \$' + totalUsd.toStringAsFixed(4) + ')';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('OS AI', style: context.theme.style((t) => t.body, (c) => c.assistantBubbleFg)),
                  const SizedBox(width: 8),
                  statusIndicator(),
                ],
              ),
              if (usageLine != null)
                Text(usageLine, style: context.theme.style((t) => t.bodySmall, (c) => c.assistantBubbleFg)),
            ],
          );
        }),
        actions: [
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
            return running ? const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ) : const SizedBox.shrink();
          }),
        ],
      ),
      body: Row(
        children: [
          ChatListSidebar(
            onCreateChat: () {
              final s = context.read<ChatStore?>();
              s?.createNewChat();
            },
            onOpenUsage: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UsageScreen()));
            },
          ),
          Expanded(
            child: Container(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
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
            ),
          ),
        ],
      ),
    );
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
                  // Cancel support
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


