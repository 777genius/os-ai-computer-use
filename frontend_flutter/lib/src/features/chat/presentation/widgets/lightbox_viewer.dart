import 'dart:convert';
import 'package:flutter/material.dart';

class LightboxViewer extends StatefulWidget {
  final List<String> base64Images;
  final int initialIndex;
  const LightboxViewer({super.key, required this.base64Images, this.initialIndex = 0});

  @override
  State<LightboxViewer> createState() => _LightboxViewerState();
}

class _LightboxViewerState extends State<LightboxViewer> {
  late final PageController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        children: [
          PageView.builder(
            controller: _ctrl,
            itemCount: widget.base64Images.length,
            itemBuilder: (_, i) {
              final bytes = const Base64Decoder().convert(widget.base64Images[i]);
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 6,
                child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
              );
            },
          ),
          Positioned(
            top: 40,
            right: 16,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.close, color: cs.onSurface),
            ),
          )
        ],
      ),
    );
  }
}


