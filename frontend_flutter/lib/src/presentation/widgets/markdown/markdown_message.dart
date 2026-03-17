import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:frontend_flutter/src/presentation/widgets/markdown/markdown_theme.dart';

/// Renders markdown text with full formatting for assistant messages
/// and minimal formatting for user messages.
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

    final config = buildMarkdownConfig(context, isUser: isUser);
    final configWithLinks = config.copy(configs: [
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

    // Use MarkdownBlock (wraps in SingleChildScrollView) for selectable content
    return MarkdownBlock(
      data: text,
      config: configWithLinks,
      selectable: true,
    );
  }
}
