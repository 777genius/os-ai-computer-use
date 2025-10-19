import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:frontend_flutter/src/presentation/theme/app_theme.dart';

class UploadItem {
  final String name;
  final int total;
  int sent;
  String? error;
  VoidCallback? cancel;
  List<int>? previewBytes; // optional small preview
  UploadItem({required this.name, required this.total, this.sent = 0, this.error, this.cancel, this.previewBytes});
}

class UploadStore extends ChangeNotifier {
  final List<UploadItem> _items = [];
  bool _visible = false;

  List<UploadItem> get items => List.unmodifiable(_items);
  bool get visible => _visible && _items.isNotEmpty;

  int get totalBytes => _items.fold(0, (a, b) => a + b.total);
  int get sentBytes => _items.fold(0, (a, b) => a + b.sent);
  int get totalCount => _items.length;
  int get completedCount => _items.where((e) => e.error != null || e.sent >= e.total).length;

  void start(String name, int total, {VoidCallback? onCancel, List<int>? previewBytes}) {
    _items.add(UploadItem(name: name, total: total, sent: 0, cancel: onCancel, previewBytes: previewBytes));
    _visible = true;
    notifyListeners();
  }

  void progress(String name, int sent, int total) {
    final idx = _items.indexWhere((e) => e.name == name && e.total == total);
    if (idx >= 0) {
      _items[idx].sent = sent;
      notifyListeners();
    }
  }

  void fail(String name, String message) {
    final idx = _items.indexWhere((e) => e.name == name);
    if (idx >= 0) {
      _items[idx].error = message;
      notifyListeners();
    }
  }

  void complete(String name) {
    _items.removeWhere((e) => e.name == name);
    if (_items.isEmpty) _visible = false;
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _visible = false;
    notifyListeners();
  }
}

class UploadOverlay extends StatelessWidget {
  const UploadOverlay({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => UploadStore(),
      child: Stack(
        children: [
          child,
          Consumer<UploadStore>(builder: (_, store, __) {
            if (!store.visible) return const SizedBox.shrink();
            final cs = Theme.of(context).colorScheme;
            final overall = store.totalBytes > 0 ? (store.sentBytes / store.totalBytes).clamp(0.0, 1.0) : 0.0;
            return Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: cs.surface,
                  border: Border(top: BorderSide(color: cs.primary.withValues(alpha: 0.25))),
                  boxShadow: [
                    BoxShadow(color: cs.primary.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, -4)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Uploading ${store.completedCount}/${store.totalCount}', style: context.theme.style((t) => t.body, (c) => c.assistantBubbleFg)),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: overall,
                                  color: cs.primary,
                                  backgroundColor: cs.primary.withValues(alpha: 0.15),
                                  minHeight: 6,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            for (final it in store.items) {
                              try { it.cancel?.call(); } catch (_) {}
                            }
                            store.clear();
                          },
                          child: const Text('Cancel all'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...store.items.map((it) {
                      final progress = it.total > 0 ? (it.sent / it.total).clamp(0.0, 1.0) : 0.0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            if (it.previewBytes != null && it.previewBytes!.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.memory(
                                  Uint8List.fromList(it.previewBytes!),
                                  width: 32,
                                  height: 32,
                                  fit: BoxFit.cover,
                                ),
                              )
                            else
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: cs.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                alignment: Alignment.center,
                                child: Icon(Icons.image, size: 16, color: cs.primary),
                              ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          it.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: context.theme.style((t) => t.bodySmall, (c) => c.assistantBubbleFg),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        it.error != null ? 'error' : ((progress * 100).toStringAsFixed(0) + '%'),
                                        style: context.theme.style((t) => t.caption, (c) => c.assistantBubbleFg),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: it.error != null ? 1.0 : progress,
                                      color: it.error != null ? Colors.red : cs.primary,
                                      backgroundColor: cs.primary.withValues(alpha: 0.15),
                                      minHeight: 6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              tooltip: 'Cancel',
                              onPressed: it.cancel == null ? null : () {
                                try { it.cancel!.call(); } catch (_) {}
                                store.complete(it.name);
                              },
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      );
                    })
                  ],
                ),
              ),
            );
          })
        ],
      ),
    );
  }
}


