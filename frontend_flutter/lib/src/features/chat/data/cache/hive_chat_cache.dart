// ignore_for_file: uri_does_not_exist, undefined_class, undefined_identifier

import 'package:hive/hive.dart';
import 'package:frontend_flutter/src/features/chat/domain/entities/chat_session.dart';
import 'package:frontend_flutter/src/features/chat/domain/entities/chat_session_mapper.dart';
import 'package:frontend_flutter/src/features/chat/domain/entities/chat_message.dart';
import 'package:frontend_flutter/src/features/chat/domain/entities/chat_message_mapper.dart';
import 'package:frontend_flutter/src/features/chat/data/cache/chat_cache.dart';

class HiveChatCache implements ChatCache {
  static const String boxName = 'chat_sessions';
  static const String messagesBoxName = 'chat_messages';

  String? _screenshotDir;

  Future<dynamic> _box() async {
    return await Hive.openBox(boxName);
  }

  Future<dynamic> _messagesBox() async {
    return await Hive.openBox(messagesBoxName);
  }

  Future<String> _getScreenshotDir() async {
    _screenshotDir ??= await getScreenshotDir();
    return _screenshotDir!;
  }

  // ── Sessions ──

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

  // ── Messages ──

  @override
  Future<List<ChatMessage>> loadMessages(String chatId) async {
    final b = await _messagesBox();
    if (b == null) return [];
    final prefix = '$chatId::';
    final out = <ChatMessage>[];
    for (final key in b.keys) {
      if (key is String && key.startsWith(prefix)) {
        final v = b.get(key);
        if (v is Map) {
          try {
            out.add(ChatMessageMapper.fromMap(v));
          } catch (_) {}
        }
      }
    }
    out.sort((a, b) => a.ts.compareTo(b.ts));
    return out;
  }

  @override
  Future<void> saveMessage(String chatId, ChatMessage message) async {
    final b = await _messagesBox();
    final dir = await _getScreenshotDir();
    final map = message.copyWith(chatId: chatId).toMap(screenshotDir: dir);
    await b?.put('$chatId::${message.id}', map);
  }

  @override
  Future<void> removeMessages(String chatId) async {
    final b = await _messagesBox();
    if (b == null) return;
    final prefix = '$chatId::';
    final keysToDelete = <dynamic>[];
    for (final key in b.keys) {
      if (key is String && key.startsWith(prefix)) {
        // Delete associated screenshot file
        final v = b.get(key);
        if (v is Map) {
          try { ChatMessageMapper.deleteScreenshot(v); } catch (_) {}
        }
        keysToDelete.add(key);
      }
    }
    await b.deleteAll(keysToDelete);
  }
}


