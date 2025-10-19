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
  final _statusCtrl = StreamController<ConnectionStatus>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _netSub;
  Stream<Map<String, dynamic>>? _mapped;
  Uri? _lastUri;
  bool _reconnecting = false;
  bool _connectedOnce = false;

  void _setupChannel(WebSocketChannel ch) {
    _ch = ch;
    _stream = ch.stream.asBroadcastStream();
    _connectedOnce = false;
    _mapped = ch.stream
        .where((ev) => ev is String)
        .map((ev) => jsonDecode(ev as String) as Map<String, dynamic>)
        .asBroadcastStream();
    _mapped!.listen((m) {
      // ignore: avoid_print
      print('[WS] msg ' + ((m['method'] ?? m['id'] ?? 'unknown')).toString());
      if (!_connectedOnce) {
        _connectedOnce = true;
        _statusCtrl.add(ConnectionStatus.connected);
      }
    });
    // ignore: avoid_print
    print('[WS] connected');
    _sub = ch.stream.listen((_) {}, onDone: () {
      // ignore: avoid_print
      print('[WS] onDone -> disconnected');
      _statusCtrl.add(ConnectionStatus.disconnected);
      _ch = null;
      _startReconnectLoop();
    }, onError: (_) {
      // ignore: avoid_print
      print('[WS] onError -> error');
      _statusCtrl.add(ConnectionStatus.error);
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
        _statusCtrl.add(ConnectionStatus.connecting);
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
    // debug prints
    // ignore: avoid_print
    print('[WS] connect uri=' + uri.toString());
    _lastUri = uri;
    try {
      _netSub ??= Connectivity().onConnectivityChanged.listen((results) {
        final hasNet = results.any((r) => r != ConnectivityResult.none);
        if (!hasNet) {
          _statusCtrl.add(ConnectionStatus.offline);
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
    while (_ch == null) {
      try {
        _statusCtrl.add(ConnectionStatus.connecting);
        // ignore: avoid_print
        print('[WS] connecting... attempt=${attempt + 1}');
        final ch = io.IOWebSocketChannel.connect(uri, pingInterval: const Duration(seconds: 10));
        _setupChannel(ch);
        break;
      } catch (_) {
        attempt += 1;
        final ms = (300 * attempt).clamp(300, 30 * 1000);
        _statusCtrl.add(ConnectionStatus.connecting);
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
    await _sub?.cancel();
    await _netSub?.cancel();
    await _ch?.sink.close();
    _ch = null;
    _stream = null;
    _statusCtrl.add(ConnectionStatus.disconnected);
    await _statusCtrl.close();
  }

  Stream<ConnectionStatus> connectionStatus() => _statusCtrl.stream;
}


