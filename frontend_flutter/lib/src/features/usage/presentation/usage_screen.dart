import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';
import 'package:frontend_flutter/src/features/chat/application/stores/chat_store.dart';
import 'package:frontend_flutter/src/presentation/theme/app_theme.dart';

class UsageScreen extends StatelessWidget {
  const UsageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Usage', style: context.theme.style((t) => t.body, (c) => c.assistantBubbleFg)),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: Observer(builder: (_) {
        final store = context.read<ChatStore?>();
        final sessions = store?.sessions ?? const [];
        final totalUsd = store?.totalUsd ?? 0.0;
        final totalIn = store?.totalInputTokens ?? 0;
        final totalOut = store?.totalOutputTokens ?? 0;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _StatCard(title: 'Total USD', value: '\$' + totalUsd.toStringAsFixed(6)),
                  _StatCard(title: 'Total input tokens', value: totalIn.toString()),
                  _StatCard(title: 'Total output tokens', value: totalOut.toString()),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: context.themeColors.surfaceBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text('By chats', style: context.theme.style((t) => t.caption, (c) => c.assistantBubbleFg)),
                            ),
                            Text('USD', style: context.theme.style((t) => t.caption, (c) => c.assistantBubbleFg)),
                            const SizedBox(width: 16),
                            Text('Tokens', style: context.theme.style((t) => t.caption, (c) => c.assistantBubbleFg)),
                            const SizedBox(width: 12),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView.separated(
                          itemCount: sessions.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final s = sessions[i];
                            final tok = s.totalInputTokens + s.totalOutputTokens;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(s.title, style: context.theme.style((t) => t.body, (c) => c.assistantBubbleFg)),
                                        if ((s.lastMessageText ?? '').isNotEmpty)
                                          Text(
                                            s.lastMessageText!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: context.theme.style((t) => t.caption, (c) => c.assistantBubbleFg),
                                          ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 100, child: Text('\$' + s.totalUsd.toStringAsFixed(6), textAlign: TextAlign.right, style: context.theme.style((t) => t.bodySmall, (c) => c.assistantBubbleFg))),
                                  const SizedBox(width: 16),
                                  SizedBox(width: 80, child: Text(tok.toString(), textAlign: TextAlign.right, style: context.theme.style((t) => t.bodySmall, (c) => c.assistantBubbleFg))),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.themeColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.theme.style((t) => t.caption, (c) => c.assistantBubbleFg)),
          const SizedBox(height: 6),
          Text(value, style: context.theme.style((t) => t.body, (c) => c.assistantBubbleFg)),
        ],
      ),
    );
  }
}


