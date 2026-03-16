import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:provider/provider.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:frontend_flutter/src/app/config/app_config.dart';
import 'package:frontend_flutter/src/features/chat/application/stores/chat_store.dart';
import 'package:frontend_flutter/src/features/chat/domain/repositories/chat_repository.dart';
import 'package:frontend_flutter/src/features/chat/presentation/utils/image_compress.dart';
import 'package:frontend_flutter/src/features/chat/presentation/widgets/upload_overlay.dart';

class ChatInputComposer extends StatefulWidget {
  const ChatInputComposer({super.key});

  @override
  State<ChatInputComposer> createState() => _ChatInputComposerState();
}

class _ChatInputComposerState extends State<ChatInputComposer> {
  final controller = TextEditingController();
  final focusNode = FocusNode();
  bool hasText = false;

  /// Pending clipboard images (attached but not yet sent).
  final List<Uint8List> _pendingImages = [];

  @override
  void initState() {
    super.initState();
    controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final newHasText = controller.text.trim().isNotEmpty;
    if (newHasText != hasText) {
      setState(() {
        hasText = newHasText;
      });
    }
  }

  @override
  void dispose() {
    controller.removeListener(_onTextChanged);
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  bool get _hasApiKey {
    final cfg = context.read<AppConfig>();
    if (cfg.activeProvider == 'openai') {
      return cfg.openaiApiKey != null && cfg.openaiApiKey!.isNotEmpty;
    }
    return cfg.anthropicApiKey != null && cfg.anthropicApiKey!.isNotEmpty;
  }

  String get _missingKeyMessage {
    final cfg = context.read<AppConfig>();
    final name = cfg.activeProvider == 'openai' ? 'OpenAI' : 'Anthropic';
    return 'Enter your $name API key in Settings first';
  }

  bool get _hasContent => hasText || _pendingImages.isNotEmpty;

  // ── Clipboard paste ──

  Future<void> _handlePaste() async {
    // Check if clipboard has text — if so, let TextField handle it
    try {
      final textData = await Clipboard.getData(Clipboard.kTextPlain);
      if (textData != null && textData.text != null && textData.text!.isNotEmpty) return;
    } catch (_) {}

    // Try reading image from clipboard via pasteboard package
    try {
      final imageBytes = await Pasteboard.image;
      if (imageBytes != null && imageBytes.isNotEmpty) {
        setState(() {
          _pendingImages.add(imageBytes);
        });
      }
    } catch (_) {}
  }

  void _removeImage(int index) {
    setState(() {
      _pendingImages.removeAt(index);
    });
  }

  // ── Upload pending images ──

  Future<void> _uploadPendingImages() async {
    if (_pendingImages.isEmpty) return;
    final repo = context.read<ChatRepository?>();
    if (repo == null) return;
    final store = context.read<UploadStore?>();
    const maxBytes = 25 * 1024 * 1024;
    final batchId = DateTime.now().microsecondsSinceEpoch.toString();
    final total = _pendingImages.length;
    final images = List<Uint8List>.from(_pendingImages);
    setState(() { _pendingImages.clear(); });

    var idx = 0;
    for (final source in images) {
      idx += 1;
      final name = 'clipboard_$idx.png';
      final cmp = await compressIfNeeded(source);
      final bytes = cmp.bytes;
      if (bytes.length > maxBytes) { store?.fail(name, 'too large'); continue; }
      final preview = await makePreviewBase64(bytes);
      var canceled = false;
      VoidCallback? cancelNetwork;
      store?.start(name, bytes.length, onCancel: () { canceled = true; cancelNetwork?.call(); });
      await repo.uploadFile(
        name, bytes,
        mime: cmp.mime,
        onProgress: (s, t) { if (!canceled) store?.progress(name, s, t); },
        onCreateCancel: (fn) { cancelNetwork = fn; },
        previewBase64: preview,
        batchId: batchId,
        batchSize: total,
        batchIndex: idx,
      );
      store?.complete(name);
    }
  }

  // ── Send ──

  Future<void> _sendMessage() async {
    final txt = controller.text.trim();
    final store = context.read<ChatStore?>();
    if (store == null) return;
    if (store.running) return;
    if (txt.isEmpty && _pendingImages.isEmpty) return;

    // Upload pending images first
    await _uploadPendingImages();

    if (txt.isNotEmpty) {
      await store.sendTask(txt);
      controller.clear();
    }
    focusNode.requestFocus();
  }

  Future<void> _stopGeneration() async {
    final repo = context.read<ChatRepository?>();
    await repo?.cancelCurrentJob();
  }

  // ── File picker ──

  Future<void> _pickFiles() async {
    final res = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
    );
    if (res == null) return;
    final repo = context.read<ChatRepository?>();
    if (repo == null) return;
    final store = context.read<UploadStore?>();
    const maxBytes = 25 * 1024 * 1024;
    final batchId = DateTime.now().microsecondsSinceEpoch.toString();
    final total = res.files.length;
    var idx = 0;
    for (final f in res.files) {
      idx += 1;
      final name = f.name;
      Uint8List? source;
      if (f.bytes != null) {
        source = Uint8List.fromList(f.bytes!);
      } else if (f.path != null && f.path!.isNotEmpty) {
        try {
          final file = File(f.path!);
          if (await file.exists()) {
            source = await file.readAsBytes();
          }
        } catch (_) {}
      }
      if (source == null) continue;
      final cmp = await compressIfNeeded(source);
      final bytes = cmp.bytes;
      if (bytes.length > maxBytes) { store?.fail(name, 'too large'); continue; }
      final preview = await makePreviewBase64(bytes);
      var canceled = false;
      VoidCallback? cancelNetwork;
      store?.start(name, bytes.length, onCancel: () { canceled = true; cancelNetwork?.call(); }, previewBytes: bytes.length > 2 * 1024 * 1024 ? null : bytes);
      final mime = cmp.mime;
      await repo.uploadFile(
        name, bytes,
        mime: mime,
        onProgress: (s, t) { if (!canceled) store?.progress(name, s, t); },
        onCreateCancel: (fn) { cancelNetwork = fn; },
        previewBase64: preview,
        batchId: batchId,
        batchSize: total,
        batchIndex: idx,
      );
      store?.complete(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Pending image previews ──
            if (_pendingImages.isNotEmpty)
              Container(
                height: 72,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _pendingImages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            _pendingImages[i],
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: -6,
                          right: -6,
                          child: GestureDetector(
                            onTap: () => _removeImage(i),
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: colorScheme.error,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

            // ── Input bar ──
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Attach file button
                  Padding(
                    padding: const EdgeInsets.only(left: 4, right: 4),
                    child: IconButton(
                      onPressed: _pickFiles,
                      icon: Icon(
                        Icons.add_circle,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      tooltip: 'Attach file',
                    ),
                  ),

                  // Text input with paste interception and Enter/Shift+Enter handling
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 0),
                      child: Focus(
                        onKeyEvent: (node, event) {
                          if (event is! KeyDownEvent) return KeyEventResult.ignored;
                          // Intercept Cmd+V / Ctrl+V for image paste
                          if (event.logicalKey == LogicalKeyboardKey.keyV &&
                              (HardwareKeyboard.instance.isMetaPressed || HardwareKeyboard.instance.isControlPressed)) {
                            _handlePaste();
                            return KeyEventResult.ignored; // let TextField paste text too
                          }
                          // Enter = send (consume event), Shift+Enter = newline (pass through)
                          if (event.logicalKey == LogicalKeyboardKey.enter &&
                              !HardwareKeyboard.instance.isShiftPressed) {
                            _sendMessage();
                            return KeyEventResult.handled; // prevent newline insertion
                          }
                          return KeyEventResult.ignored;
                        },
                        child: TextField(
                          controller: controller,
                          focusNode: focusNode,
                          minLines: 1,
                          maxLines: 5,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            hintText: 'Give me a task...',
                            hintStyle: TextStyle(
                              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Right side buttons
                  Padding(
                    padding: const EdgeInsets.only(left: 4, right: 4),
                    child: Observer(
                      builder: (_) {
                        final store = context.read<ChatStore?>();
                        final isRunning = store?.running ?? false;
                        if (isRunning) {
                          return IconButton(
                            onPressed: _stopGeneration,
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: colorScheme.error,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.stop_rounded, color: Colors.white, size: 20),
                            ),
                            tooltip: 'Stop generation',
                          );
                        } else if (_hasContent) {
                          final keyOk = _hasApiKey;
                          return Tooltip(
                            message: keyOk ? 'Send message' : _missingKeyMessage,
                            child: IconButton(
                              onPressed: keyOk ? _sendMessage : null,
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: keyOk
                                      ? colorScheme.primary
                                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.arrow_upward_rounded,
                                  color: keyOk ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                                  size: 20,
                                ),
                              ),
                            ),
                          );
                        } else {
                          return IconButton(
                            onPressed: () {
                              launchUrl(Uri.parse('https://voicetext.site/'));
                            },
                            icon: Icon(Icons.mic_none_outlined, color: colorScheme.onSurfaceVariant),
                            tooltip: 'Voice input',
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            // ── Hotkey hint when agent is running ──
            Observer(
              builder: (_) {
                final store = context.read<ChatStore?>();
                if (store?.running ?? false) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Press Ctrl+Esc to stop the agent (works globally)',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }
}
