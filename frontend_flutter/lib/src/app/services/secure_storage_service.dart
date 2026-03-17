import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:injectable/injectable.dart';

/// Persistent encrypted file storage for API keys and settings.
///
/// Uses AES-256-CBC with a key derived from a per-machine salt.
/// Keys are stored in an encrypted JSON file inside the app support directory.
/// Both Anthropic and OpenAI keys are stored simultaneously.
@lazySingleton
class SecureStorageService {
  static const String _fileName = 'keys.enc';

  // Storage keys
  static const String _anthropicApiKeyKey = 'anthropic_api_key';
  static const String _openaiApiKeyKey = 'openai_api_key';
  static const String _hasCompletedSetupKey = 'has_completed_setup';
  static const String _activeProviderKey = 'active_provider';
  static const String _userPreferencesKey = 'user_preferences';

  Map<String, String>? _cache;
  bool _loaded = false;

  // ── Encryption helpers ──

  /// Derive a 32-byte AES key from machine-specific data + app salt.
  enc.Key _deriveKey() {
    final host = Platform.localHostname;
    final user = Platform.environment['USER'] ?? Platform.environment['USERNAME'] ?? '';
    final raw = 'os-ai:$host:$user:f7a3c9e1-salt';
    final hash = sha256.convert(utf8.encode(raw));
    return enc.Key(Uint8List.fromList(hash.bytes));
  }

  /// Fixed 16-byte IV derived from salt (stable across runs).
  enc.IV _deriveIV() {
    final raw = 'os-ai-iv:stable-vector';
    final hash = md5.convert(utf8.encode(raw));
    return enc.IV(Uint8List.fromList(hash.bytes));
  }

  String _encrypt(String plaintext) {
    final encrypter = enc.Encrypter(enc.AES(_deriveKey(), mode: enc.AESMode.cbc));
    return encrypter.encrypt(plaintext, iv: _deriveIV()).base64;
  }

  String _decrypt(String cipherBase64) {
    final encrypter = enc.Encrypter(enc.AES(_deriveKey(), mode: enc.AESMode.cbc));
    return encrypter.decrypt64(cipherBase64, iv: _deriveIV());
  }

  // ── File I/O ──

  Future<File> _getFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<Map<String, String>> _load() async {
    if (_loaded && _cache != null) return _cache!;
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final cipherText = await file.readAsString();
        if (cipherText.trim().isNotEmpty) {
          final json = _decrypt(cipherText);
          final decoded = jsonDecode(json) as Map<String, dynamic>;
          _cache = decoded.map((k, v) => MapEntry(k, v.toString()));
          _loaded = true;
          return _cache!;
        }
      }
    } catch (e) {
      // Corrupted file or key change — start fresh
    }
    _cache = {};
    _loaded = true;
    return _cache!;
  }

  Future<void> _save() async {
    final data = _cache ?? {};
    final json = jsonEncode(data);
    final cipherText = _encrypt(json);
    final file = await _getFile();
    await file.writeAsString(cipherText, flush: true);
  }

  Future<String?> _get(String key) async {
    final store = await _load();
    final val = store[key];
    return (val != null && val.isNotEmpty) ? val : null;
  }

  Future<void> _set(String key, String value) async {
    final store = await _load();
    store[key] = value;
    await _save();
  }

  Future<void> _remove(String key) async {
    final store = await _load();
    store.remove(key);
    await _save();
  }

  // ── Public API (same interface as before) ──

  // Anthropic API Key

  Future<void> saveAnthropicApiKey(String apiKey) => _set(_anthropicApiKeyKey, apiKey);
  Future<String?> getAnthropicApiKey() => _get(_anthropicApiKeyKey);
  Future<bool> hasAnthropicApiKey() async => (await getAnthropicApiKey()) != null;
  Future<void> deleteAnthropicApiKey() => _remove(_anthropicApiKeyKey);

  // OpenAI API Key

  Future<void> saveOpenAIApiKey(String apiKey) => _set(_openaiApiKeyKey, apiKey);
  Future<String?> getOpenAIApiKey() => _get(_openaiApiKeyKey);
  Future<bool> hasOpenAIApiKey() async => (await getOpenAIApiKey()) != null;
  Future<void> deleteOpenAIApiKey() => _remove(_openaiApiKeyKey);

  // Active provider

  Future<void> saveActiveProvider(String provider) => _set(_activeProviderKey, provider);
  Future<String?> getActiveProvider() => _get(_activeProviderKey);

  // User preferences

  Future<void> saveUserPreferences(String prefs) => _set(_userPreferencesKey, prefs);
  Future<String?> getUserPreferences() => _get(_userPreferencesKey);
  Future<void> deleteUserPreferences() => _remove(_userPreferencesKey);

  // Setup tracking

  Future<void> markSetupComplete() => _set(_hasCompletedSetupKey, 'true');

  Future<bool> hasCompletedSetup() async {
    return (await _get(_hasCompletedSetupKey)) == 'true';
  }

  // Utility

  Future<void> clearAll() async {
    _cache = {};
    _loaded = true;
    final file = await _getFile();
    if (await file.exists()) await file.delete();
  }

  Future<Map<String, String?>> getAllApiKeys() async {
    await _load();
    return {
      'anthropic': await _get(_anthropicApiKeyKey),
      'openai': await _get(_openaiApiKeyKey),
    };
  }
}
