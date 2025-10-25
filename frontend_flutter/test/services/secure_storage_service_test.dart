import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/src/app/services/secure_storage_service.dart';

void main() {
  group('SecureStorageService', () {
    late SecureStorageService service;

    setUp(() {
      service = SecureStorageService();
    });

    test('should create service instance', () {
      expect(service, isNotNull);
      expect(service, isA<SecureStorageService>());
    });

    test('should have saveAnthropicApiKey method', () {
      // Validates API exists
      expect(service.saveAnthropicApiKey, isA<Function>());
    });

    test('should have getAnthropicApiKey method', () {
      // Validates API exists
      expect(service.getAnthropicApiKey, isA<Function>());
    });

    test('should have hasAnthropicApiKey method', () {
      // Validates API exists
      expect(service.hasAnthropicApiKey, isA<Function>());
    });

    test('should have deleteAnthropicApiKey method', () {
      // Validates API exists
      expect(service.deleteAnthropicApiKey, isA<Function>());
    });

    test('should have getAllApiKeys method', () {
      // Validates API exists
      expect(service.getAllApiKeys, isA<Function>());
    });

    test('should have OpenAI key methods', () {
      // Validates OpenAI API key methods exist
      expect(service.saveOpenAIApiKey, isA<Function>());
      expect(service.getOpenAIApiKey, isA<Function>());
      expect(service.hasOpenAIApiKey, isA<Function>());
      expect(service.deleteOpenAIApiKey, isA<Function>());
    });

    test('should have setup tracking methods', () {
      // Validates setup tracking
      expect(service.markSetupComplete, isA<Function>());
      expect(service.hasCompletedSetup, isA<Function>());
    });
  });
}
