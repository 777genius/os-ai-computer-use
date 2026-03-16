import 'package:frontend_flutter/src/features/chat/domain/entities/chat_session.dart';
import 'package:frontend_flutter/src/features/chat/domain/entities/chat_message.dart';

abstract class ChatCache {
  // Sessions
  Future<List<ChatSession>> loadSessions();
  Future<void> upsertSession(ChatSession session);
  Future<void> removeSession(String id);

  // Messages
  Future<List<ChatMessage>> loadMessages(String chatId);
  Future<void> saveMessage(String chatId, ChatMessage message);
  Future<void> removeMessages(String chatId);
}



