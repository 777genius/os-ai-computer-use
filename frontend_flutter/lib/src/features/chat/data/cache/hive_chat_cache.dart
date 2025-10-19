// ignore_for_file: uri_does_not_exist, undefined_class, undefined_identifier

import 'package:hive/hive.dart';
import 'package:frontend_flutter/src/features/chat/domain/entities/chat_session.dart';
import 'package:frontend_flutter/src/features/chat/domain/entities/chat_session_mapper.dart';
import 'package:frontend_flutter/src/features/chat/data/cache/chat_cache.dart';

class HiveChatCache implements ChatCache {
  static const String boxName = 'chat_sessions';

  Future<dynamic> _box() async {
    // Открываем box с Map-сообщениями (адаптеры не требуются)
    return await Hive.openBox(boxName);
  }

  @override
  Future<List<ChatSession>> loadSessions() async {
    final b = await _box();
    final values = (b?.values as Iterable?) ?? const <dynamic>[];
    final out = <ChatSession>[];
    for (final v in values) {
      if (v is Map) {
        try {
          out.add(ChatSessionMapper.fromMap(v));
        } catch (_) {}
      }
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  @override
  Future<void> upsertSession(ChatSession session) async {
    final b = await _box();
    await b?.put(session.id, session.toMap());
  }

  @override
  Future<void> removeSession(String id) async {
    final b = await _box();
    await b?.delete(id);
  }
}


