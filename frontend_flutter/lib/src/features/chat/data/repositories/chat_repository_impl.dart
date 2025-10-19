import 'dart:async';
import 'dart:convert';
import 'package:injectable/injectable.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:frontend_flutter/src/features/chat/domain/entities/chat_message.dart';
import 'package:frontend_flutter/src/features/chat/domain/entities/cost_usage.dart';
import 'package:frontend_flutter/src/features/chat/domain/repositories/chat_repository.dart';
import 'package:frontend_flutter/src/features/chat/data/datasources/backend_ws_client.dart';
import 'package:frontend_flutter/src/features/chat/data/datasources/backend_rest_client.dart';
import 'package:frontend_flutter/src/features/chat/domain/entities/cost_rates.dart';
import 'package:frontend_flutter/src/features/chat/domain/entities/connection_status.dart';

@LazySingleton(as: ChatRepository)
class ChatRepositoryImpl implements ChatRepository {
  final BackendWsClient _ws;
  final BackendRestClient _rest;
  final Uri Function() _wsUriProvider;
  ChatRepositoryImpl(this._ws, this._rest, {Uri Function()? wsUriProvider})
      : _wsUriProvider = wsUriProvider ?? (() => Uri.parse('ws://127.0.0.1:8765/ws?token=secret'));

  final _msgCtrl = StreamController<ChatMessage>.broadcast();
  final _usageCtrl = StreamController<CostUsage>.broadcast();
  final _runningCtrl = StreamController<bool>.broadcast();
  final _statusCtrl = StreamController<ConnectionStatus>.broadcast();
  StreamSubscription? _wsMessagesSub;
  StreamSubscription? _wsStatusSub;
  bool _wsListening = false;
  String? _currentJobId;
  String? _thinkingMsgId;
  int _historyPairsLimit = 6;
  final List<ChatMessage> _historyText = [];
  final Map<String, List<ChatMessage>> _historyTextByChat = {};
  final Map<String, List<Map<String, String>>> _albumBuffer = {};
  final Map<String, int> _albumTarget = {};
  final List<Map<String, String?>> _pendingAttachments = [];
  ConnectionStatus _lastWsStatus = ConnectionStatus.connecting;
  bool _lastHealthOk = false;
  Timer? _healthTimer;
  bool _wsConnecting = false;
  ConnectionStatus? _lastEffectiveStatus;
  // Если пользователь нажал стоп до того, как пришёл реальный jobId (UUID),
  // сохраняем намерение отмены и отправляем cancel сразу после маппинга reqId->jobId
  bool _pendingCancel = false;

  String? _sessionId;
  String? _activeChatId;
  final Map<String, String> _jobChat = {}; // jobId -> chatId
  final Map<String, String> _pendingJobs = {}; // reqId -> chatId

  @override
  Stream<ChatMessage> messages() => _msgCtrl.stream;

  @override
  Stream<CostUsage> usage() => _usageCtrl.stream;

  @override
  Stream<bool> running() => _runningCtrl.stream;

  @override
  Stream<ConnectionStatus> connectionStatus() => _statusCtrl.stream;

  int _id = 0;
  String _nextId() => (++_id).toString();

  @override
  Future<String> createSession({String? provider}) async {
    try {
      await _ws.connect(_wsUriProvider());
      if (!_wsListening) {
        _wsListening = true;
        _wsMessagesSub = _ws.messages.listen(_onWs, onDone: () {
          _runningCtrl.add(false);
          _msgCtrl.add(ChatMessage(
            id: _nextId(),
            role: 'assistant',
            ts: DateTime.now(),
            kind: 'text',
            text: 'Server connection closed.',
          ));
        }, onError: (_) {
          _runningCtrl.add(false);
          _msgCtrl.add(ChatMessage(
            id: _nextId(),
            role: 'assistant',
            ts: DateTime.now(),
            kind: 'text',
            text: 'Server connection error.',
          ));
        });
        // Monitor WS status and start health checks
        _wsStatusSub = _ws.connectionStatus().listen((s) {
          _lastWsStatus = s;
          _emitEffectiveStatus();
        });
        _startHealthChecks();
      }
    } catch (_) {
      _runningCtrl.add(false);
      return '';
    }
    // Immediately probe session to force early server response -> flips status to connected when backend is alive
    final pingId = _nextId();
    _ws.send({'jsonrpc': '2.0', 'id': pingId, 'method': 'session.create', 'params': {}});
    final completer = Completer<String>();
    final id = _nextId();
    void sub(Map<String, dynamic> m) {
      if (m['id'] == id && m['result'] is Map<String, dynamic>) {
        final r = m['result'] as Map<String, dynamic>;
        _sessionId = r['sessionId'] as String?;
        completer.complete(_sessionId ?? '');
      }
    }
    final s = _ws.messages.listen(sub);
    _ws.send({
      'jsonrpc': '2.0',
      'id': id,
      'method': 'session.create',
      'params': {'provider': provider},
    });
    final sid = await completer.future.timeout(const Duration(seconds: 5), onTimeout: () => '');
    await s.cancel();
    return sid;
  }

  @override
  void setActiveChat(String chatId) {
    _activeChatId = chatId;
  }

  void _onWs(Map<String, dynamic> m) {
    // ignore: avoid_print
    print('[Repo] WS <- ' + (m['method']?.toString() ?? 'resp id=' + (m['id']?.toString() ?? 'unknown')));
    // Track last message time to stabilize effective connection status
    _emitEffectiveStatus();
    if (m.containsKey('method')) {
      final method = m['method'] as String;
      if (method == 'event.log') {
        final p = m['params'] as Map<String, dynamic>;
        final msg = (p['message'] as String?) ?? '';
        // ignore: avoid_print
        print('[Repo] event.log: ' + msg);
        // Если это tool_result ок, рисуем галочку
        if (msg.startsWith('done:') || msg.startsWith('ok') || msg.toLowerCase().contains('tool_result')) {
          final lastAction = _lastActionNameFromQueue();
          _msgCtrl.add(ChatMessage(
            id: _nextId(),
            role: 'assistant',
            ts: DateTime.now(),
            kind: 'action',
            text: '✔ ' + (lastAction ?? 'ok'),
            meta: {'name': lastAction ?? 'ok', 'status': 'ok'},
          ));
          return;
        }
        // Fallback: планы Anthropic в логах
        if (msg.startsWith('ANTHROPIC_TOOL_USE:')) {
          try {
            final raw = msg.substring('ANTHROPIC_TOOL_USE:'.length);
            final parsed = jsonDecode(raw);
            if (parsed is List) {
              for (final b in parsed) {
                String? name;
                Map<String, dynamic>? input;
                if (b is Map) {
                  name = b['name'] as String?;
                  final i = b['input'];
                  if (i is Map) input = i.cast<String, dynamic>();
                }
                _msgCtrl.add(ChatMessage(
                  id: _nextId(),
                  role: 'assistant',
                  ts: DateTime.now(),
                  kind: 'action',
                  text: _formatPlannedActionText(name, input),
                  meta: {'name': name, 'status': 'plan', 'meta': input},
                ));
              }
              return;
            }
          } catch (_) {}
        }
        final cmThought = ChatMessage(
          id: _nextId(),
          role: 'assistant',
          ts: DateTime.now(),
          kind: 'thought',
          text: msg.isEmpty ? null : msg,
        );
        _msgCtrl.add(cmThought);
        _recordHistory(cmThought, chatId: _jobChat[_currentJobId ?? ''] ?? _activeChatId);
      } else if (method == 'event.screenshot') {
        final p = m['params'] as Map<String, dynamic>;
        // ignore: avoid_print
        print('[Repo] event.screenshot len=' + ((p['data'] as String?)?.length.toString() ?? '0'));
        _msgCtrl.add(ChatMessage(
          id: _nextId(),
          role: 'assistant',
          ts: DateTime.now(),
          kind: 'screenshot',
          imageBase64: p['data'] as String?,
        ));
      } else if (method == 'event.action') {
        final p = m['params'] as Map<String, dynamic>;
        final name = p['name'] as String?;
        final status = p['status'] as String?;
        final meta = (p['meta'] as Map?)?.cast<String, dynamic>();
        // ignore: avoid_print
        print('[Repo] event.action: ' + (name ?? '') + ' [' + (status ?? '') + ']');
        _rememberActionName(meta, name);
        final cmAction = ChatMessage(
          id: _nextId(),
          role: 'assistant',
          ts: DateTime.now(),
          kind: 'action',
          text: _formatActionText(name, status, meta),
          meta: {'name': name, 'status': status, 'meta': meta},
        );
        _msgCtrl.add(cmAction);
      } else if (method == 'event.progress') {
        final p = m['params'] as Map<String, dynamic>;
        final stage = (p['stage'] as String? ?? '').toLowerCase();
        if (stage == 'cancelled') {
          _runningCtrl.add(false);
          // remove the Thinking... bubble
          _thinkingMsgId = null;
        }
      } else if (method == 'event.usage') {
        final p = m['params'] as Map<String, dynamic>;
        final inTok = (p['input_tokens'] as num? ?? 0).toInt();
        final outTok = (p['output_tokens'] as num? ?? 0).toInt();
        // ignore: avoid_print
        print('[Repo] event.usage in=' + inTok.toString() + ' out=' + outTok.toString());
        final u = CostUsage(
          inputTokens: inTok,
          outputTokens: outTok,
          inputUsd: CostRates.inputUsdFor(inTok),
          outputUsd: CostRates.outputUsdFor(outTok),
        );
        _usageCtrl.add(u);
        final cmUsage = ChatMessage(
          id: _nextId(),
          role: 'assistant',
          ts: DateTime.now(),
          kind: 'usage',
          text: 'in=' + inTok.toString() + ' out=' + outTok.toString() + '  cost=\$' + u.totalUsd.toStringAsFixed(6) + ' (input=\$' + u.inputUsd.toStringAsFixed(6) + ', output=\$' + u.outputUsd.toStringAsFixed(6) + ')',
          meta: {
            'inputTokens': inTok,
            'outputTokens': outTok,
            'inputUsd': u.inputUsd,
            'outputUsd': u.outputUsd,
            'totalUsd': u.totalUsd,
            if (_activeChatId != null) 'chatId': _activeChatId,
          },
        );
        _msgCtrl.add(cmUsage);
      } else if (method == 'event.final') {
        // ignore: avoid_print
        print('[Repo] event.final');
        // Закомментировано: скрываем сводное финальное сообщение из UI
        // final text = p['text'] as String?;
        // if (text != null && text.isNotEmpty) {
        //   final cmFinal = ChatMessage(
        //     id: _nextId(),
        //     role: 'assistant',
        //     ts: DateTime.now(),
        //     kind: 'text',
        //     text: text,
        //   );
        //   _msgCtrl.add(cmFinal);
        //   _recordHistory(cmFinal, chatId: _jobChat[_currentJobId ?? ''] ?? _activeChatId);
        // }
        // remove the Thinking... bubble when job finishes
        if (_thinkingMsgId != null) {
          _msgCtrl.add(ChatMessage(
            id: _nextId(),
            role: 'assistant',
            ts: DateTime.now(),
            kind: 'control',
            text: null,
            meta: {'removeMessageId': _thinkingMsgId},
          ));
          _thinkingMsgId = null;
        }
        if (_currentJobId != null) {
          _jobChat.remove(_currentJobId);
          _currentJobId = null;
        }
        _runningCtrl.add(false);
      }
      return;
    }
    // Handle responses by id if needed
    try {
      final respId = (m['id']?.toString());
      if (respId != null) {
        final chatId = _pendingJobs.remove(respId);
        if (chatId != null) {
          final res = m['result'];
          if (res is Map) {
            final jobId = res['jobId']?.toString();
            if (jobId != null && jobId.isNotEmpty) {
              _jobChat[jobId] = chatId;
              // Update _currentJobId with the real jobId (UUID) from backend
              if (respId == _currentJobId) {
                _currentJobId = jobId;
                // ignore: avoid_print
                print('[Repo] Updated _currentJobId from reqId=$respId to jobId=$jobId');
                // Если отмена была запрошена до получения jobId — отправляем cancel сейчас
                if (_pendingCancel) {
                  _pendingCancel = false;
                  final cid = _nextId();
                  _ws.send({'jsonrpc': '2.0', 'id': cid, 'method': 'agent.cancel', 'params': {'jobId': jobId}});
                }
              }
            }
          }
        }
      }
    } catch (_) {}
  }

  @override
  Future<String> runTask({required String task}) async {
    final id = _nextId();
    if (_activeChatId != null) {
      _pendingJobs[id] = _activeChatId!;
    }
    _msgCtrl.add(ChatMessage(id: _nextId(), role: 'user', ts: DateTime.now(), kind: 'text', text: task));
    _thinkingMsgId = _nextId();
    _msgCtrl.add(ChatMessage(id: _thinkingMsgId!, role: 'assistant', ts: DateTime.now(), kind: 'thought', text: 'Thinking...', meta: const {'thinking': true}));
    _runningCtrl.add(true);
    _ws.send({
      'jsonrpc': '2.0',
      'id': id,
      'method': 'agent.run',
      'params': {
        'task': task,
        'maxIterations': 30,
        // передаем короткий контекст из последних сообщений как текстовые пары
        'context': _buildContext(),
        if (_pendingAttachments.isNotEmpty) 'attachments': List<Map<String, String?>>.from(_pendingAttachments),
      },
    });
    _currentJobId = id;
    _pendingCancel = false;
    // attachments одноразовые: привязываем к ближайшей задаче
    _pendingAttachments.clear();
    return id;
  }

  @override
  Future<void> cancelJob(String jobId) async {
    final id = _nextId();
    // ignore: avoid_print
    print('[Repo] Cancelling jobId=$jobId');
    _ws.send({'jsonrpc': '2.0', 'id': id, 'method': 'agent.cancel', 'params': {'jobId': jobId}});
  }

  @override
  Future<void> cancelCurrentJob() async {
    final jid = _currentJobId;
    if (jid == null) return;
    if (_isProbablyUuid(jid)) {
      await cancelJob(jid);
    } else {
      // jobId ещё не известен (используется временный reqId) — пометим отмену на потом
      _pendingCancel = true;
    }
    // Немедленно погасим флаг выполнения, чтобы кнопка стоп скрылась в UI
    _runningCtrl.add(false);
    _msgCtrl.add(ChatMessage(id: _nextId(), role: 'assistant', ts: DateTime.now(), kind: 'text', text: 'Stopped by user.'));
  }

  @override
  Future<String> uploadFile(String name, List<int> bytes, {String? mime, void Function(int, int)? onProgress, void Function(void Function())? onCreateCancel, String? previewBase64, String? batchId, int? batchSize, int? batchIndex}) async {
    // Retry with backoff and resume on connectivity
    bool cancelled = false;
    String id = '';
    Future<void> waitForConnectivity() async {
      try {
        final c = Connectivity();
        var state = await c.checkConnectivity();
        if (state == ConnectivityResult.none) {
          await c.onConnectivityChanged.firstWhere((s) => s != ConnectivityResult.none);
        }
      } catch (_) {}
    }
    void _wrapOnCreateCancel(void Function() fn) {
      void wrapper() {
        cancelled = true;
        try { fn(); } catch (_) {}
      }
      try { onCreateCancel?.call(wrapper); } catch (_) {}
    }
    int attempt = 0;
    while (true) {
      attempt += 1;
      try {
        id = await _rest.uploadBytes(name, bytes, mime: mime, onProgress: onProgress, onCreateCancel: _wrapOnCreateCancel);
        break;
      } catch (e) {
        if (cancelled || attempt >= 3) {
          rethrow;
        }
        // backoff: 1s, 2s then wait connectivity
        final delay = attempt == 1 ? const Duration(seconds: 1) : const Duration(seconds: 2);
        await Future.delayed(delay);
        await waitForConnectivity();
      }
    }
    // emit attachment message for UI
    _msgCtrl.add(ChatMessage(
      id: _nextId(),
      role: 'user',
      ts: DateTime.now(),
      kind: 'attachment',
      text: name,
      meta: {
        'fileId': id,
        'name': name,
        if (mime != null) 'mime': mime,
        if (previewBase64 != null) 'previewBase64': previewBase64,
        if (batchId != null) 'batchId': batchId,
        if (batchSize != null) 'batchSize': batchSize,
        if (batchIndex != null) 'batchIndex': batchIndex,
      },
    ));
    _pendingAttachments.add({'fileId': id, 'name': name, 'mime': mime});

    // Collect album items if batch is provided
    if (batchId != null && batchSize != null && batchSize > 1) {
      final list = _albumBuffer.putIfAbsent(batchId, () => <Map<String, String>>[]);
      _albumTarget[batchId] = batchSize;
      list.add({
        'fileId': id,
        'name': name,
        if (previewBase64 != null) 'previewBase64': previewBase64,
      });
      if (list.length >= (_albumTarget[batchId] ?? 0)) {
        // Emit album message
        _msgCtrl.add(ChatMessage(
          id: _nextId(),
          role: 'user',
          ts: DateTime.now(),
          kind: 'attachment_album',
          text: 'Album (' + list.length.toString() + ')',
          meta: {
            'items': List<Map<String, String>>.from(list),
          },
        ));
        _albumBuffer.remove(batchId);
        _albumTarget.remove(batchId);
      }
    }
    return id;
  }

  @override
  Future<List<int>> downloadFile(String id) async {
    return await _rest.downloadBytes(id);
  }

  String _formatActionText(String? name, String? status, Map<String, dynamic>? meta) {
    final b = StringBuffer();
    if (name != null) b.write(name);
    if (status != null) b.write(' [' + status + ']');
    if (meta != null && meta.isNotEmpty) {
      b.write(' ');
      b.write(meta.toString());
    }
    return b.toString();
  }

  bool _isProbablyUuid(String s) {
    // Бэкенд использует uuid4 c дефисами, тогда как request-id у нас простой инкремент ("1","2",...)
    return s.contains('-');
  }

  String _formatPlannedActionText(String? name, Map<String, dynamic>? input) {
    final b = StringBuffer('PLAN: ');
    if (name != null) b.write(name);
    if (input != null && input.isNotEmpty) {
      b.write(' ');
      b.write(input.toString());
    }
    return b.toString();
  }

  void _startHealthChecks() {
    _healthTimer ??= Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final res = await _rest.healthz().timeout(const Duration(seconds: 2));
        _lastHealthOk = res.isNotEmpty;
      } catch (_) {
        _lastHealthOk = false;
      }
      // If backend is healthy but WS isn't connected, try to (re)connect
      if (_lastHealthOk && _lastWsStatus != ConnectionStatus.connected && !_wsConnecting) {
        _wsConnecting = true;
        try {
          await _ws.connect(_wsUriProvider());
        } catch (_) {}
        _wsConnecting = false;
      }
      _emitEffectiveStatus();
    });
  }

  void _emitEffectiveStatus() {
    ConnectionStatus eff;
    switch (_lastWsStatus) {
      case ConnectionStatus.offline:
        eff = ConnectionStatus.offline;
        break;
      case ConnectionStatus.error:
        eff = ConnectionStatus.error;
        break;
      case ConnectionStatus.disconnected:
        eff = ConnectionStatus.connecting;
        break;
      case ConnectionStatus.connecting:
        eff = ConnectionStatus.connecting;
        break;
      case ConnectionStatus.connected:
        // treat as connected when WS is connected and last health check is OK
        eff = _lastHealthOk ? ConnectionStatus.connected : ConnectionStatus.connecting;
        break;
    }
    // de-duplicate to avoid UI flicker
    if (_lastEffectiveStatus != eff) {
      _lastEffectiveStatus = eff;
      _statusCtrl.add(eff);
    }
  }

  List<Map<String, String>> _buildContext({int maxPairs = 6}) {
    try {
      final list = <Map<String, String>>[];
      final src = _activeChatId != null ? (_historyTextByChat[_activeChatId!] ?? _historyText) : _historyText;
      for (final m in src.take(maxPairs)) {
        final t = m.text?.trim();
        if (t == null || t.isEmpty) continue;
        final role = (m.role == 'user' || m.role == 'assistant') ? m.role : 'assistant';
        list.add({'role': role, 'text': t});
      }
      return list;
    } catch (_) {
      return const [];
    }
  }

  String? _lastActionNameFromQueue() {
    // Небольшой хак: пробуем найти последнее действие по последним action-сообщениям
    // (в рамках этой простой реализации можно расширить хранением отдельной очереди)
    return null;
  }

  void _rememberActionName(Map<String, dynamic>? meta, String? name) {
    // Заготовка под будущий state, чтобы знать последнее действие
  }

  void _recordHistory(ChatMessage m, {String? chatId}) {
    if (m.kind == 'text' || m.kind == 'thought') {
      if (chatId != null && chatId.isNotEmpty) {
        final list = _historyTextByChat.putIfAbsent(chatId, () => <ChatMessage>[]);
        list.insert(0, m);
        final cap = _historyPairsLimit * 2;
        if (list.length > cap) {
          list.removeRange(cap, list.length);
        }
      } else {
        _historyText.insert(0, m);
        final cap = _historyPairsLimit * 2;
        if (_historyText.length > cap) {
          _historyText.removeRange(cap, _historyText.length);
        }
      }
    }
  }

  /// Cleanup resources to prevent memory leaks
  Future<void> dispose() async {
    await _wsMessagesSub?.cancel();
    await _wsStatusSub?.cancel();
    _healthTimer?.cancel();
    await _msgCtrl.close();
    await _usageCtrl.close();
    await _runningCtrl.close();
    await _statusCtrl.close();
  }
}


