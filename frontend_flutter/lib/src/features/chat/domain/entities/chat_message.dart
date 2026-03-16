import 'package:equatable/equatable.dart';

class ChatMessage extends Equatable {
  final String id;
  final String role; // 'user' | 'assistant' | 'system'
  final String? chatId; // owning chat session
  final String? kind; // 'thought' | 'action' | 'screenshot' | 'usage' | 'text'
  final String? text;
  final String? imageBase64; // optional screenshot
  final Map<String, dynamic>? meta; // additional data for rendering
  final DateTime ts;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.ts,
    this.chatId,
    this.kind,
    this.text,
    this.imageBase64,
    this.meta,
  });

  ChatMessage copyWith({
    String? id,
    String? role,
    String? chatId,
    String? kind,
    String? text,
    String? imageBase64,
    Map<String, dynamic>? meta,
    DateTime? ts,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      chatId: chatId ?? this.chatId,
      ts: ts ?? this.ts,
      kind: kind ?? this.kind,
      text: text ?? this.text,
      imageBase64: imageBase64 ?? this.imageBase64,
      meta: meta ?? this.meta,
    );
  }

  @override
  List<Object?> get props => [id, role, chatId, kind, text, imageBase64, meta, ts];
}


