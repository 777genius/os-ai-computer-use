import 'dart:async';
import 'dart:convert';

import 'package:injectable/injectable.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:frontend_flutter/src/features/chat/domain/entities/connection_status.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart' as io;

@lazySingleton
class BackendWsClient {
  WebSocketChannel? _ch;
  // Deprecated: kept for compatibility; will be removed once unused across codebase
  // ignore: unused_field
  Stream<dynamic>? _stream;
  StreamSubscription? _sub;
  StreamSubscription? _mappedSub;
  final _statusCtrl = StreamController<ConnectionStatus>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _netSub;
  Stream<Map<String, dynamic>>? _mapped;
  Uri? _lastUri;
  bool _reconnecting = false;
  bool _connectedOnce = false;
  bool _isClosed = false;

  /// Helper to safely add status events, checking if controller is closed
  void _addStatus(ConnectionStatus status) {
    if (!_isClosed && !_statusCtrl.isClosed) {
      try {
        _statusCtrl.add(status);
      } catch (_) {
        // Ignore - controller may have been closed concurrently
      }
    }
  }

  void _setupChannel(WebSocketChannel ch) {
    _ch = ch;
    _stream = ch.stream.asBroadcastStream();
    _connectedOnce = false;
    _mapped = ch.stream
        .where((ev) => ev is String)
        .map((ev) => jsonDecode(ev as String) as Map<String, dynamic>)
        .asBroadcastStream();
    _mappedSub = _mapped!.listen((m) {
      // ignore: avoid_print
      print('[WS] msg ' + ((m['method'] ?? m['id'] ?? 'unknown')).toString());
      if (!_connectedOnce) {
        _connectedOnce = true;
        _addStatus(ConnectionStatus.connected);
      }
    });
    // ignore: avoid_print
    print('[WS] connected');
    _sub = ch.stream.listen((_) {}, onDone: () {
      // ignore: avoid_print
      print('[WS] onDone -> disconnected');
      _addStatus(ConnectionStatus.disconnected);
      _ch = null;
      _startReconnectLoop();
    }, onError: (_) {
      // ignore: avoid_print
      print('[WS] onError -> error');
      _addStatus(ConnectionStatus.error);
      _ch = null;
      _startReconnectLoop();
    }, cancelOnError: false);
  }

  Future<void> _startReconnectLoop() async {
    if (_reconnecting) return;
    if (_lastUri == null) return;
    _reconnecting = true;
    int attempt = 0;
    while (_ch == null && _lastUri != null) {
      try {
        _addStatus(ConnectionStatus.connecting);
        final ms = (300 * (attempt + 1)).clamp(300, 30000);
        // ignore: avoid_print
        print('[WS] reconnect attempt=${attempt + 1} backoffMs=' + ms.toString());
        final ch = io.IOWebSocketChannel.connect(_lastUri!, pingInterval: const Duration(seconds: 10));
        _setupChannel(ch);
        break;
      } catch (_) {
        attempt += 1;
        final ms = (300 * attempt).clamp(300, 30000);
        await Future.delayed(Duration(milliseconds: ms));
      }
    }
    _reconnecting = false;
  }

  Future<void> connect(Uri uri) async {
    // debug prints (без query параметров - там API ключи!)
    // ignore: avoid_print
    print('[WS] connect to ${uri.host}:${uri.port}${uri.path}');
    _lastUri = uri;
    try {
      _netSub ??= Connectivity().onConnectivityChanged.listen((results) {
        final hasNet = results.any((r) => r != ConnectivityResult.none);
        if (!hasNet) {
          _addStatus(ConnectionStatus.offline);
          // ignore: avoid_print
          print('[WS] network -> offline');
        } else {
          // Net restored; if not connected, try to reconnect
          if (_ch == null) {
            _startReconnectLoop();
          }
        }
      });
    } catch (_) {
      // Плагина может не быть (desktop dev). Игнорируем.
    }
    int attempt = 0;
    const maxAttempts = 10;  // Prevent infinite loop
    while (_ch == null && attempt < maxAttempts) {
      try {
        _addStatus(ConnectionStatus.connecting);
        // ignore: avoid_print
        print('[WS] connecting... attempt=${attempt + 1}/$maxAttempts');
        final ch = io.IOWebSocketChannel.connect(uri, pingInterval: const Duration(seconds: 10));
        _setupChannel(ch);
        break;
      } catch (_) {
        attempt += 1;
        if (attempt >= maxAttempts) {
          // ignore: avoid_print
          print('[WS] Failed to connect after $maxAttempts attempts');
          _addStatus(ConnectionStatus.error);
          break;
        }
        final ms = (300 * attempt).clamp(300, 30 * 1000);
        _addStatus(ConnectionStatus.connecting);
        // ignore: avoid_print
        print('[WS] connect retry after ' + ms.toString() + 'ms');
        await Future.delayed(Duration(milliseconds: ms));
      }
    }
  }

  Stream<Map<String, dynamic>> get messages => _mapped ?? const Stream.empty();

  void send(Map<String, dynamic> msg) {
    _ch?.sink.add(jsonEncode(msg));
  }

  Future<void> close() async {
    // Guard against double close
    if (_isClosed) return;
    _isClosed = true;

    try {
      // Cancel all subscriptions
      await _sub?.cancel();
      await _mappedSub?.cancel();
      await _netSub?.cancel();

      // Close WebSocket
      await _ch?.sink.close();
      _ch = null;
      _stream = null;

      // Send final status before closing controller
      _addStatus(ConnectionStatus.disconnected);

      // Close status controller
      await _statusCtrl.close();
    } catch (e) {
      // ignore: avoid_print
      print('[WS] Error during close: $e');
    }
  }

  Stream<ConnectionStatus> connectionStatus() => _statusCtrl.stream;
}


