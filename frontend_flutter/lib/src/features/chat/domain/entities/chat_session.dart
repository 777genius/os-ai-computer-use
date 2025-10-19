import 'package:equatable/equatable.dart';

class ChatSession extends Equatable {
  final String id;
  final String title;
  final DateTime createdAt;
  final double totalUsd;
  final int totalInputTokens;
  final int totalOutputTokens;
  final String? lastMessageText;

  const ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    this.totalUsd = 0.0,
    this.totalInputTokens = 0,
    this.totalOutputTokens = 0,
    this.lastMessageText,
  });

  ChatSession copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    double? totalUsd,
    int? totalInputTokens,
    int? totalOutputTokens,
    String? lastMessageText,
  }) {
    return ChatSession(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      totalUsd: totalUsd ?? this.totalUsd,
      totalInputTokens: totalInputTokens ?? this.totalInputTokens,
      totalOutputTokens: totalOutputTokens ?? this.totalOutputTokens,
      lastMessageText: lastMessageText ?? this.lastMessageText,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        createdAt,
        totalUsd,
        totalInputTokens,
        totalOutputTokens,
        lastMessageText,
      ];
}



