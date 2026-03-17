import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/a11y-light.dart';
import 'package:markdown_widget/markdown_widget.dart';

import 'package:frontend_flutter/src/presentation/widgets/markdown/markdown_code_block.dart';

Widget _wrapCode(Widget child, String code, String language) =>
    MarkdownCodeBlock(code: code, language: language, child: child);

/// Builds a [MarkdownConfig] adapted to the current theme brightness.
MarkdownConfig buildMarkdownConfig(BuildContext context, {bool isUser = false}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final colorScheme = Theme.of(context).colorScheme;
  final textColor = isUser ? Colors.white : colorScheme.onSurface;

  final baseConfig = isDark ? MarkdownConfig.darkConfig : MarkdownConfig.defaultConfig;

  return baseConfig.copy(configs: [
    // Paragraph
    PConfig(textStyle: TextStyle(fontSize: 14, height: 1.5, color: textColor)),

    // Headings
    H1Config(style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: textColor)),
    H2Config(style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: textColor)),
    H3Config(style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
    H4Config(style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
    H5Config(style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
    H6Config(style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),

    // Inline code
    CodeConfig(style: TextStyle(
      fontSize: 13,
      fontFamily: 'monospace',
      backgroundColor: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF0F0F0),
      color: isDark ? const Color(0xFFE0E0E0) : const Color(0xFF333333),
    )),

    // Code blocks
    isDark
        ? PreConfig.darkConfig.copy(
            wrapper: _wrapCode,
            textStyle: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(8),
            ),
          )
        : PreConfig(
            wrapper: _wrapCode,
            textStyle: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            theme: a11yLightTheme,
            decoration: BoxDecoration(
              color: const Color(0xFFF6F8FA),
              borderRadius: BorderRadius.circular(8),
            ),
          ),

    // Links
    LinkConfig(
      style: TextStyle(
        color: colorScheme.primary,
        decoration: TextDecoration.underline,
      ),
    ),

    // Blockquote
    BlockquoteConfig(
      sideColor: colorScheme.primary.withValues(alpha: 0.5),
      textColor: textColor.withValues(alpha: 0.8),
    ),

    // Horizontal rule
    HrConfig(color: colorScheme.outline.withValues(alpha: 0.3)),

    // Table
    TableConfig(
      headerStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: textColor),
      bodyStyle: TextStyle(fontSize: 13, color: textColor),
      border: TableBorder.all(
        color: colorScheme.outline.withValues(alpha: 0.2),
        width: 0.5,
      ),
      headerRowDecoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
      ),
    ),

    // List
    ListConfig(
      marker: (isOrdered, depth, index) {
        if (isOrdered) {
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(
              '${index + 1}.',
              style: TextStyle(fontSize: 14, color: textColor),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(right: 6, top: 6),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: textColor.withValues(alpha: 0.6),
            ),
          ),
        );
      },
    ),
  ]);
}
