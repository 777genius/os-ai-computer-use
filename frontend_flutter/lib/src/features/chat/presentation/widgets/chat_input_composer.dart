import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:file_picker/file_picker.dart';
import 'package:frontend_flutter/src/features/chat/application/stores/chat_store.dart';
import 'package:frontend_flutter/src/features/chat/domain/repositories/chat_repository.dart';
import 'package:frontend_flutter/src/features/chat/presentation/utils/image_compress.dart';
import 'dart:typed_data';
import 'package:frontend_flutter/src/features/chat/presentation/widgets/upload_overlay.dart';
import 'dart:io';

class ChatInputComposer extends StatefulWidget {
  const ChatInputComposer({super.key});

  @override
  State<ChatInputComposer> createState() => _ChatInputComposerState();
}

class _ChatInputComposerState extends State<ChatInputComposer> {
  final controller = TextEditingController();
  final focusNode = FocusNode();
  bool hasText = false;

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

  Future<void> _sendMessage() async {
    final txt = controller.text.trim();
    final store = context.read<ChatStore?>();
    if (txt.isEmpty || store == null) return;
    await store.sendTask(txt);
    controller.clear();
    focusNode.requestFocus();
  }

  Future<void> _stopGeneration() async {
    final repo = context.read<ChatRepository?>();
    await repo?.cancelCurrentJob();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Container(
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
              // Add file button (placeholder)
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 4),
                child: IconButton(
                  onPressed: () async {
                    final res = await FilePicker.platform.pickFiles(withData: true, allowMultiple: true, type: FileType.custom, allowedExtensions: ['png','jpg','jpeg','webp']);
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
                        name,
                        bytes,
                        mime: mime,
                        onProgress: (s,t){ if (!canceled) store?.progress(name, s, t); },
                        onCreateCancel: (fn){ cancelNetwork = fn; },
                        previewBase64: preview,
                        batchId: batchId,
                        batchSize: total,
                        batchIndex: idx,
                      );
                      store?.complete(name);
                    }
                  },
                  icon: Icon(
                    Icons.add_circle,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  tooltip: 'Attach file',
                ),
              ),
              
              // Text input field
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 0),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      hintText: 'Give me a task...',
                      hintStyle: TextStyle(
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                    ),
                    onSubmitted: (_) => _sendMessage(),
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
                      // Stop button when bot is thinking
                      return IconButton(
                        onPressed: _stopGeneration,
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.error,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.stop_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        tooltip: 'Stop generation',
                      );
                    } else if (hasText) {
                      // Send button when there's text
                      return IconButton(
                        onPressed: _sendMessage,
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_upward_rounded,
                            color: colorScheme.onPrimary,
                            size: 20,
                          ),
                        ),
                        tooltip: 'Send message',
                      );
                    } else {
                      // Microphone button (placeholder) when no text
                      return IconButton(
                        onPressed: () {
                          // TODO: Implement voice input
                        },
                        icon: Icon(
                          Icons.mic_none_outlined,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        tooltip: 'Voice input',
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


