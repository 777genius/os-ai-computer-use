import 'package:flutter/foundation.dart';

class AppConfig extends ChangeNotifier {
  String host;
  int port;
  String token;
  int historyPairsLimit;
  String? anthropicApiKey;
  String? openaiApiKey;
  String activeProvider;

  AppConfig({
    this.host = '127.0.0.1',
    this.port = 8765,
    this.token = 'secret',
    this.historyPairsLimit = 6,
    this.anthropicApiKey,
    this.openaiApiKey,
    this.activeProvider = 'anthropic',
  });

  Uri wsUri() {
    final uri = Uri.parse('ws://$host:$port/ws?token=$token');
    final extra = <String, String>{};

    if (anthropicApiKey != null && anthropicApiKey!.isNotEmpty) {
      extra['anthropic_api_key'] = anthropicApiKey!;
    }
    if (openaiApiKey != null && openaiApiKey!.isNotEmpty) {
      extra['openai_api_key'] = openaiApiKey!;
    }

    if (extra.isNotEmpty) {
      return uri.replace(queryParameters: {
        ...uri.queryParameters,
        ...extra,
      });
    }

    return uri;
  }

  String restBase() => 'http://$host:$port';

  void update({
    String? host,
    int? port,
    String? token,
    int? historyPairsLimit,
    String? anthropicApiKey,
    String? openaiApiKey,
    String? activeProvider,
  }) {
    bool changed = false;
    if (host != null && host != this.host) {
      this.host = host;
      changed = true;
    }
    if (port != null && port != this.port) {
      this.port = port;
      changed = true;
    }
    if (token != null && token != this.token) {
      this.token = token;
      changed = true;
    }
    if (historyPairsLimit != null && historyPairsLimit != this.historyPairsLimit) {
      this.historyPairsLimit = historyPairsLimit;
      changed = true;
    }
    if (anthropicApiKey != null && anthropicApiKey != this.anthropicApiKey) {
      this.anthropicApiKey = anthropicApiKey;
      changed = true;
    }
    if (openaiApiKey != null && openaiApiKey != this.openaiApiKey) {
      this.openaiApiKey = openaiApiKey;
      changed = true;
    }
    if (activeProvider != null && activeProvider != this.activeProvider) {
      this.activeProvider = activeProvider;
      changed = true;
    }
    if (changed) notifyListeners();
  }
}


