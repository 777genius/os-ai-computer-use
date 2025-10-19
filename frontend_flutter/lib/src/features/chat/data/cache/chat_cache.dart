import 'package:frontend_flutter/src/features/chat/domain/entities/chat_session.dart';

abstract class ChatCache {
  Future<List<ChatSession>> loadSessions();
  Future<void> upsertSession(ChatSession session);
  Future<void> removeSession(String id);
}



