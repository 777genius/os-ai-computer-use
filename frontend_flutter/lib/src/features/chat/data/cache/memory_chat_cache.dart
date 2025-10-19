import 'package:frontend_flutter/src/features/chat/data/cache/chat_cache.dart';
import 'package:frontend_flutter/src/features/chat/domain/entities/chat_session.dart';

class MemoryChatCache implements ChatCache {
  final Map<String, ChatSession> _map = {};

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
}



