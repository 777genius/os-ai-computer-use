import 'package:frontend_flutter/src/features/chat/data/cache/chat_cache.dart';
import 'package:frontend_flutter/src/features/chat/domain/entities/chat_session.dart';
import 'package:frontend_flutter/src/features/chat/domain/entities/chat_message.dart';

class MemoryChatCache implements ChatCache {
  final Map<String, ChatSession> _map = {};
  final Map<String, List<ChatMessage>> _messages = {};

  // ── Sessions ──

  @override
  Future<List<ChatSession>> loadSessions() async {
    return _map.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<void> removeSession(String id) async {
    _map.remove(id);
  }

  @override
  Future<void> upsertSession(ChatSession session) async {
    _map[session.id] = session;
  }

  // ── Messages ──

  @override
  Future<List<ChatMessage>> loadMessages(String chatId) async {
    return List.of(_messages[chatId] ?? []);
  }

  @override
  Future<void> saveMessage(String chatId, ChatMessage message) async {
    _messages.putIfAbsent(chatId, () => []).add(message);
  }

  @override
  Future<void> removeMessages(String chatId) async {
    _messages.remove(chatId);
  }
}



