import 'package:frontend_flutter/src/features/chat/domain/entities/chat_session.dart';

extension ChatSessionMapper on ChatSession {
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'totalUsd': totalUsd,
      'totalInputTokens': totalInputTokens,
      'totalOutputTokens': totalOutputTokens,
      'lastMessageText': lastMessageText,
    };
  }

  static ChatSession fromMap(Map map) {
    return ChatSession(
      id: (map['id'] as String?) ?? '',
      title: (map['title'] as String?) ?? 'Chat',
      createdAt: DateTime.tryParse((map['createdAt'] as String?) ?? '') ?? DateTime.now(),
      totalUsd: (map['totalUsd'] as num?)?.toDouble() ?? 0.0,
      totalInputTokens: (map['totalInputTokens'] as num?)?.toInt() ?? 0,
      totalOutputTokens: (map['totalOutputTokens'] as num?)?.toInt() ?? 0,
      lastMessageText: (map['lastMessageText'] as String?),
    );
  }
}



