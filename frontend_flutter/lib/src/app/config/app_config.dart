import 'package:flutter/foundation.dart';

class AppConfig extends ChangeNotifier {
  String host;
  int port;
  String token;
  int historyPairsLimit;
  String? anthropicApiKey;
  String? openaiApiKey;
  String? azureOpenAIApiKey;
  String? azureOpenAIEndpoint;
  String? azureOpenAIDeployment;
  String? azureOpenAIApiVersion;
  String activeProvider;
  String? userPreferences;

  AppConfig({
    this.host = '127.0.0.1',
    this.port = 8765,
    this.token = 'secret',
    this.historyPairsLimit = 6,
    this.anthropicApiKey,
    this.openaiApiKey,
    this.azureOpenAIApiKey,
    this.azureOpenAIEndpoint,
    this.azureOpenAIDeployment = 'computer-use-preview',
    this.azureOpenAIApiVersion = '2025-04-01-preview',
    this.activeProvider = 'anthropic',
    this.userPreferences,
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
    if (azureOpenAIApiKey != null && azureOpenAIApiKey!.isNotEmpty) {
      extra['azure_openai_api_key'] = azureOpenAIApiKey!;
    }
    if (azureOpenAIEndpoint != null && azureOpenAIEndpoint!.isNotEmpty) {
      extra['azure_openai_endpoint'] = azureOpenAIEndpoint!;
    }
    if (azureOpenAIDeployment != null && azureOpenAIDeployment!.isNotEmpty) {
      extra['azure_openai_deployment'] = azureOpenAIDeployment!;
    }
    if (azureOpenAIApiVersion != null && azureOpenAIApiVersion!.isNotEmpty) {
      extra['azure_openai_api_version'] = azureOpenAIApiVersion!;
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
    String? azureOpenAIApiKey,
    String? azureOpenAIEndpoint,
    String? azureOpenAIDeployment,
    String? azureOpenAIApiVersion,
    String? activeProvider,
    String? userPreferences,
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
    if (historyPairsLimit != null &&
        historyPairsLimit != this.historyPairsLimit) {
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
    if (azureOpenAIApiKey != null &&
        azureOpenAIApiKey != this.azureOpenAIApiKey) {
      this.azureOpenAIApiKey = azureOpenAIApiKey;
      changed = true;
    }
    if (azureOpenAIEndpoint != null &&
        azureOpenAIEndpoint != this.azureOpenAIEndpoint) {
      this.azureOpenAIEndpoint = azureOpenAIEndpoint;
      changed = true;
    }
    if (azureOpenAIDeployment != null &&
        azureOpenAIDeployment != this.azureOpenAIDeployment) {
      this.azureOpenAIDeployment = azureOpenAIDeployment;
      changed = true;
    }
    if (azureOpenAIApiVersion != null &&
        azureOpenAIApiVersion != this.azureOpenAIApiVersion) {
      this.azureOpenAIApiVersion = azureOpenAIApiVersion;
      changed = true;
    }
    if (activeProvider != null && activeProvider != this.activeProvider) {
      this.activeProvider = activeProvider;
      changed = true;
    }
    if (userPreferences != null && userPreferences != this.userPreferences) {
      this.userPreferences = userPreferences;
      changed = true;
    }
    if (changed) notifyListeners();
  }
}
