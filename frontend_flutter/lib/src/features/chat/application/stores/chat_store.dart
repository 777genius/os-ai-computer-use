import 'package:mobx/mobx.dart';
import 'package:frontend_flutter/src/features/chat/domain/entities/chat_message.dart';
import 'package:frontend_flutter/src/features/chat/domain/entities/cost_usage.dart';
import 'package:frontend_flutter/src/features/chat/domain/entities/chat_session.dart';
import 'package:frontend_flutter/src/features/chat/domain/repositories/chat_repository.dart';
// injectable не используем для ChatStore, создаётся через Provider
import 'package:frontend_flutter/src/features/chat/data/cache/chat_cache.dart';
import 'package:frontend_flutter/src/features/chat/domain/entities/connection_status.dart';

part 'chat_store.g.dart';

class ChatStore = _ChatStore with _$ChatStore;

abstract class _ChatStore with Store {
  final ChatRepository repo;
  final ChatCache? cache;
  _ChatStore(this.repo, {this.cache}) {
    // Ensure at least one chat exists
    final firstId = _generateChatId();
    final first = ChatSession(id: firstId, title: 'Chat 1', createdAt: DateTime.now());
    sessions.add(first);
    activeChatId = firstId;
    _messagesByChat[firstId] = ObservableList.of([]);
    messages = _messagesByChat[firstId]!;

    // Wire streams
    repo.messages().listen((m) {
      final cid = _messageChatId ?? activeChatId;
      // Handle control messages (e.g., remove placeholders)
      if ((m.kind ?? '') == 'control') {
        final rid = (m.meta?['removeMessageId'] as String?) ?? '';
        if (rid.isNotEmpty) {
          _removeMessageById(cid, rid);
        }
        return;
      }
      _appendMessageTo(cid, m);
      _updateLastPreviewFor(cid, m.text);
      // Keep Thinking... bubble as the last message while running
      _ensureThinkingLast(cid);
    });
    repo.usage().listen((u) {
      usage = u;
      totalUsd += u.totalUsd;
      totalInputTokens += u.inputTokens;
      totalOutputTokens += u.outputTokens;
      // per-chat aggregation: attribute to the chat that started current job
      final cid = _usageChatId ?? activeChatId;
      final prevUsd = perChatUsd[cid] ?? 0.0;
      perChatUsd[cid] = prevUsd + u.totalUsd;
      perChatInTokens[cid] = (perChatInTokens[cid] ?? 0) + u.inputTokens;
      perChatOutTokens[cid] = (perChatOutTokens[cid] ?? 0) + u.outputTokens;
      _updateSessionUsage(cid);
    });
    repo.running().listen((r) {
      running = r;
      if (r) {
        // mark which chat will receive upcoming usage and messages
        _usageChatId = activeChatId;
        _messageChatId = activeChatId;
      } else {
        _messageChatId = null;
        _usageChatId = null;
      }
    });
    repo.connectionStatus().listen((s) => connection = s);
  }

  // Sessions and per-chat state
  @observable
  ObservableList<ChatSession> sessions = ObservableList.of([]);

  @observable
  String activeChatId = '';

  final ObservableMap<String, ObservableList<ChatMessage>> _messagesByChat = ObservableMap.of({});

  @observable
  ObservableList<ChatMessage> messages = ObservableList.of([]);

  // Per-chat usage aggregation
  @observable
  ObservableMap<String, double> perChatUsd = ObservableMap.of({});

  @observable
  ObservableMap<String, int> perChatInTokens = ObservableMap.of({});

  @observable
  ObservableMap<String, int> perChatOutTokens = ObservableMap.of({});

  // Global aggregates
  @observable
  CostUsage? usage;

  @observable
  double totalUsd = 0.0;

  @observable
  int totalInputTokens = 0;

  @observable
  int totalOutputTokens = 0;

  @observable
  bool running = false;

  @observable
  ConnectionStatus connection = ConnectionStatus.connecting;

  String? _usageChatId;
  String? _messageChatId;

  @action
  Future<void> sendTask(String text) async {
    _usageChatId = activeChatId;
    _messageChatId = activeChatId;
    await repo.runTask(task: text);
  }

  @action
  Future<void> init() async {
    try {
      // init hive if needed
      // (инициализацию Hive вынесем в main, здесь только чтение)
      final saved = await cache?.loadSessions();
      if (saved != null && saved.isNotEmpty) {
        sessions = ObservableList.of(saved);
        activeChatId = saved.first.id;
        _messagesByChat[activeChatId] = ObservableList.of([]);
        messages = _messagesByChat[activeChatId]!;
        try { repo.setActiveChat(activeChatId); } catch (_) {}
      }
    } catch (_) {}
    await repo.createSession();
    try {
      // scoped config fetch placeholder
    } catch (_) {}
  }

  @action
  String createNewChat({String? title}) {
    final id = _generateChatId();
    final c = ChatSession(id: id, title: title?.trim().isNotEmpty == true ? title!.trim() : 'Chat ' + (sessions.length + 1).toString(), createdAt: DateTime.now());
    sessions.insert(0, c);
    try { cache?.upsertSession(c); } catch (_) {}
    _messagesByChat[id] = ObservableList.of([]);
    perChatUsd[id] = 0.0;
    perChatInTokens[id] = 0;
    perChatOutTokens[id] = 0;
    activeChatId = id;
    messages = _messagesByChat[id]!;
    try { repo.setActiveChat(id); } catch (_) {}
    return id;
  }

  @action
  void setActiveChat(String id) {
    if (id == activeChatId) return;
    if (!_messagesByChat.containsKey(id)) {
      _messagesByChat[id] = ObservableList.of([]);
    }
    activeChatId = id;
    messages = _messagesByChat[id]!;
    try { repo.setActiveChat(id); } catch (_) {}
  }

  @action
  void renameChat(String id, String title) {
    final idx = sessions.indexWhere((s) => s.id == id);
    if (idx >= 0) {
      final s = sessions[idx];
      final next = s.copyWith(title: title);
      sessions[idx] = next;
      try { cache?.upsertSession(next); } catch (_) {}
    }
  }

  @action
  void removeChat(String id) {
    sessions.removeWhere((s) => s.id == id);
    _messagesByChat.remove(id);
    perChatUsd.remove(id);
    perChatInTokens.remove(id);
    perChatOutTokens.remove(id);
    try { cache?.removeSession(id); } catch (_) {}
    if (activeChatId == id) {
      if (sessions.isNotEmpty) {
        activeChatId = sessions.first.id;
        messages = _messagesByChat[activeChatId] ?? ObservableList.of([]);
        try { repo.setActiveChat(activeChatId); } catch (_) {}
      } else {
        final nid = createNewChat();
        activeChatId = nid;
        messages = _messagesByChat[activeChatId] ?? ObservableList.of([]);
        try { repo.setActiveChat(activeChatId); } catch (_) {}
      }
    }
  }

  void _appendMessageTo(String chatId, ChatMessage m) {
    final list = _messagesByChat[chatId] ??= ObservableList.of([]);
    list.add(m);
    if (chatId == activeChatId && messages != list) {
      messages = list;
    }
    // Передвинем чат вверх при новой активности
    final idx = sessions.indexWhere((s) => s.id == chatId);
    if (idx > 0) {
      final s = sessions.removeAt(idx);
      sessions.insert(0, s);
    }
  }

  void _removeMessageById(String chatId, String id) {
    final list = _messagesByChat[chatId];
    if (list == null) return;
    list.removeWhere((e) => e.id == id);
    if (chatId == activeChatId && messages != list) {
      messages = list;
    }
  }

  void _ensureThinkingLast(String chatId) {
    final list = _messagesByChat[chatId];
    if (list == null || list.isEmpty) return;
    // find current Thinking... bubble
    final idx = list.lastIndexWhere((e) => (e.meta?['thinking'] as bool?) == true);
    if (idx < 0) return;
    if (idx == list.length - 1) return; // already last
    final item = list.removeAt(idx);
    list.add(item);
    if (chatId == activeChatId && messages != list) {
      messages = list;
    }
  }

  void _updateLastPreviewFor(String chatId, String? text) {
    if (text == null || text.isEmpty) return;
    final idx = sessions.indexWhere((s) => s.id == chatId);
    if (idx >= 0) {
      final s = sessions[idx];
      final next = s.copyWith(lastMessageText: text);
      sessions[idx] = next;
      try { cache?.upsertSession(next); } catch (_) {}
    }
  }

  void _updateSessionUsage(String chatId) {
    final idx = sessions.indexWhere((s) => s.id == chatId);
    if (idx >= 0) {
      final s = sessions[idx];
      final next = s.copyWith(
        totalUsd: perChatUsd[chatId] ?? 0.0,
        totalInputTokens: perChatInTokens[chatId] ?? 0,
        totalOutputTokens: perChatOutTokens[chatId] ?? 0,
      );
      sessions[idx] = next;
      try { cache?.upsertSession(next); } catch (_) {}
    }
  }

  String _generateChatId() => DateTime.now().microsecondsSinceEpoch.toString();
}


