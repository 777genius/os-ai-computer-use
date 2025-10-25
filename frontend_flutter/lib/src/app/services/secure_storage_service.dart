import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

/// Service for securely storing sensitive data like API keys
/// Uses platform-specific secure storage:
/// - macOS: Keychain
/// - Windows: Credential Manager
/// - Linux: libsecret
/// - Web: Encrypted localStorage
@lazySingleton
class SecureStorageService {
  final FlutterSecureStorage _storage;

  // Storage keys
  static const String _anthropicApiKeyKey = 'anthropic_api_key';
  static const String _openaiApiKeyKey = 'openai_api_key';
  static const String _hasCompletedSetupKey = 'has_completed_setup';

  SecureStorageService()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(
            encryptedSharedPreferences: true,
          ),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock,
          ),
        );

  // Anthropic API Key methods

  /// Save Anthropic API key securely
  Future<void> saveAnthropicApiKey(String apiKey) async {
    await _storage.write(key: _anthropicApiKeyKey, value: apiKey);
  }

  /// Get Anthropic API key
  Future<String?> getAnthropicApiKey() async {
    return await _storage.read(key: _anthropicApiKeyKey);
  }

  /// Check if Anthropic API key exists
  Future<bool> hasAnthropicApiKey() async {
    final key = await getAnthropicApiKey();
    return key != null && key.isNotEmpty;
  }

  /// Delete Anthropic API key
  Future<void> deleteAnthropicApiKey() async {
    await _storage.delete(key: _anthropicApiKeyKey);
  }

  // OpenAI API Key methods

  /// Save OpenAI API key securely
  Future<void> saveOpenAIApiKey(String apiKey) async {
    await _storage.write(key: _openaiApiKeyKey, value: apiKey);
  }

  /// Get OpenAI API key
  Future<String?> getOpenAIApiKey() async {
    return await _storage.read(key: _openaiApiKeyKey);
  }

  /// Check if OpenAI API key exists
  Future<bool> hasOpenAIApiKey() async {
    final key = await getOpenAIApiKey();
    return key != null && key.isNotEmpty;
  }

  /// Delete OpenAI API key
  Future<void> deleteOpenAIApiKey() async {
    await _storage.delete(key: _openaiApiKeyKey);
  }

  // Setup tracking

  /// Mark that user has completed initial setup
  Future<void> markSetupComplete() async {
    await _storage.write(key: _hasCompletedSetupKey, value: 'true');
  }

  /// Check if user has completed initial setup
  Future<bool> hasCompletedSetup() async {
    final value = await _storage.read(key: _hasCompletedSetupKey);
    return value == 'true';
  }

  // Utility methods

  /// Clear all stored data (useful for logout/reset)
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  /// Get all API keys at once for initialization
  Future<Map<String, String?>> getAllApiKeys() async {
    final anthropicKey = await getAnthropicApiKey();
    final openaiKey = await getOpenAIApiKey();

    return {
      'anthropic': anthropicKey,
      'openai': openaiKey,
    };
  }
}
