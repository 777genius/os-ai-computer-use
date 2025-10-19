import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend_flutter/src/presentation/theme/app_theme.dart';
import 'package:frontend_flutter/src/features/chat/presentation/widgets/lightbox_viewer.dart';

class AlbumBubble extends StatelessWidget {
  final List<Map<String, String>> items; // [{fileId,name,previewBase64?}]
  final bool isUser;
  const AlbumBubble({super.key, required this.items, this.isUser = true});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isUser ? context.themeColors.userBubbleBg : context.themeColors.assistantBubbleBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Album (' + items.length.toString() + ')', style: isUser
                ? context.theme.style((t) => t.bodySmall, (c) => c.userBubbleFg)
                : context.theme.style((t) => t.bodySmall, (c) => c.assistantBubbleFg)),
            const SizedBox(height: 8),
            LayoutBuilder(builder: (context, constraints) {
              final w = constraints.maxWidth;
              final cross = w > 420 ? 3 : (w > 280 ? 2 : 1);
              final previews = <String>[];
              final indexMap = <int, int>{};
              for (int j = 0; j < items.length; j++) {
                final p = items[j]['previewBase64'];
                if (p != null && p.isNotEmpty) {
                  indexMap[j] = previews.length;
                  previews.add(p);
                }
              }
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cross,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                ),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final it = items[i];
                  final preview = it['previewBase64'];
                  if (preview != null && preview.isNotEmpty) {
                    final initial = indexMap[i];
                    return GestureDetector(
                      onTap: initial == null
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => LightboxViewer(base64Images: previews, initialIndex: initial),
                                ),
                              );
                            },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(const Base64Decoder().convert(preview), fit: BoxFit.cover),
                      ),
                    );
                  }
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: cs.onSurface.withValues(alpha: 0.08),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.image, color: cs.onSurfaceVariant),
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}


