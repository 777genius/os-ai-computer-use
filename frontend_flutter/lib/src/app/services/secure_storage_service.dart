import 'package:injectable/injectable.dart';

/// Temporary in-memory storage for API keys and settings.
///
/// TODO: Replace with persistent secure storage (Keychain / flutter_secure_storage)
/// once macOS code signing with DEVELOPMENT_TEAM is fully resolved.
/// Current issue: Keychain returns -34018 even with entitlements + DEVELOPMENT_TEAM
/// configured. Data is lost when the app restarts.
@lazySingleton
class SecureStorageService {
  final Map<String, String> _store = {};

  // Storage keys
  static const String _anthropicApiKeyKey = 'anthropic_api_key';
  static const String _openaiApiKeyKey = 'openai_api_key';
  static const String _hasCompletedSetupKey = 'has_completed_setup';
  static const String _activeProviderKey = 'active_provider';

  // Anthropic API Key methods

  Future<void> saveAnthropicApiKey(String apiKey) async {
    _store[_anthropicApiKeyKey] = apiKey;
  }

  Future<String?> getAnthropicApiKey() async {
    return _store[_anthropicApiKeyKey];
  }

  Future<bool> hasAnthropicApiKey() async {
    final key = await getAnthropicApiKey();
    return key != null && key.isNotEmpty;
  }

  Future<void> deleteAnthropicApiKey() async {
    _store.remove(_anthropicApiKeyKey);
  }

  // OpenAI API Key methods

  Future<void> saveOpenAIApiKey(String apiKey) async {
    _store[_openaiApiKeyKey] = apiKey;
  }

  Future<String?> getOpenAIApiKey() async {
    return _store[_openaiApiKeyKey];
  }

  Future<bool> hasOpenAIApiKey() async {
    final key = await getOpenAIApiKey();
    return key != null && key.isNotEmpty;
  }

  Future<void> deleteOpenAIApiKey() async {
    _store.remove(_openaiApiKeyKey);
  }

  // Active provider selection

  Future<void> saveActiveProvider(String provider) async {
    _store[_activeProviderKey] = provider;
  }

  Future<String?> getActiveProvider() async {
    return _store[_activeProviderKey];
  }

  // Setup tracking

  Future<void> markSetupComplete() async {
    _store[_hasCompletedSetupKey] = 'true';
  }

  Future<bool> hasCompletedSetup() async {
    return _store[_hasCompletedSetupKey] == 'true';
  }

  // Utility methods

  Future<void> clearAll() async {
    _store.clear();
  }

  Future<Map<String, String?>> getAllApiKeys() async {
    return {
      'anthropic': _store[_anthropicApiKeyKey],
      'openai': _store[_openaiApiKeyKey],
    };
  }
}
