import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:frontend_flutter/src/presentation/widgets/markdown/markdown_theme.dart';

/// Renders markdown text with full formatting for assistant messages.
class MarkdownMessage extends StatelessWidget {
  final String text;
  final bool isUser;

  const MarkdownMessage({
    super.key,
    required this.text,
    this.isUser = false,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();

    final fallbackColor = isUser
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;

    try {
      final config =
          buildMarkdownConfig(context, isUser: isUser).copy(configs: [
        LinkConfig(
          style: TextStyle(
            color: isUser
                ? Colors.white.withValues(alpha: 0.9)
                : Theme.of(context).colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
          onTap: (url) {
            final uri = Uri.tryParse(url);
            if (uri != null) launchUrl(uri);
          },
        ),
      ]);

      // Use MarkdownGenerator directly to produce widgets,
      // avoiding nested ScrollView / Column issues.
      final generator = MarkdownGenerator();
      final widgets = generator.buildWidgets(text, config: config);

      if (widgets.isEmpty) {
        return Text(text, style: TextStyle(color: fallbackColor));
      }

      return SelectionArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: widgets,
        ),
      );
    } catch (e) {
      debugPrint('MarkdownMessage error: $e');
      return Text(text, style: TextStyle(color: fallbackColor));
    }
  }
}
