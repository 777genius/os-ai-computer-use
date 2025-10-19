import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:frontend_flutter/src/features/chat/domain/repositories/chat_repository.dart';
import 'package:frontend_flutter/src/presentation/theme/app_theme.dart';

class AttachmentBubble extends StatelessWidget {
  final String name;
  final String fileId;
  final bool isUser;
  final String? previewBase64;
  const AttachmentBubble({super.key, required this.name, required this.fileId, this.isUser = true, this.previewBase64});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: isUser ? context.themeColors.userBubbleBg : context.themeColors.assistantBubbleBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (previewBase64 != null && previewBase64!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.memory(
                  const Base64Decoder().convert(previewBase64!),
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                ),
              )
            else
              Icon(Icons.attach_file, color: isUser ? context.themeColors.userBubbleFg : context.themeColors.assistantBubbleFg, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: isUser
                    ? context.theme.style((t) => t.body, (c) => c.userBubbleFg)
                    : context.theme.style((t) => t.body, (c) => c.assistantBubbleFg),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () async {
                final repo = context.read<ChatRepository?>();
                if (repo == null) return;
                final bytes = await repo.downloadFile(fileId);
                final dir = await getTemporaryDirectory();
                final path = dir.path + '/' + name;
                final f = await File(path).writeAsBytes(bytes, flush: true);
                await OpenFilex.open(f.path);
              },
              child: const Text('Open'),
            ),
          ],
        ),
      ),
    );
  }
}


