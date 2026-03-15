import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/src/app/services/api_key_validator.dart';

void main() {
  group('ApiKeyValidator', () {
    late ApiKeyValidator validator;

    setUp(() {
      validator = ApiKeyValidator();
    });

    group('Anthropic API key validation', () {
      test('should accept valid Anthropic API key format', () {
        // Valid Anthropic key: sk-ant- + 95+ characters
        final validKey = 'sk-ant-' + 'a' * 95;
        final result = validator.validateAnthropicKey(validKey);
        expect(result.isValid, true);
        expect(result.error, isNull);
      });

      test('should reject empty Anthropic API key', () {
        final result = validator.validateAnthropicKey('');
        expect(result.isValid, false);
        expect(result.error, contains('empty'));
      });

      test('should reject invalid Anthropic API key prefix', () {
        final result = validator.validateAnthropicKey('invalid-key-format');
        expect(result.isValid, false);
        expect(result.error, contains('sk-ant'));
      });

      test('should reject Anthropic key that is too short', () {
        final result = validator.validateAnthropicKey('sk-ant-short');
        expect(result.isValid, false);
        expect(result.error, isNotNull);
      });
    });

    group('OpenAI API key validation', () {
      test('should accept valid OpenAI API key format', () {
        // Valid OpenAI key: sk- + 32+ characters
        final validKey = 'sk-' + 'a' * 32;
        final result = validator.validateOpenAIKey(validKey);
        expect(result.isValid, true);
        expect(result.error, isNull);
      });

      test('should accept sk-proj- format key with dashes and underscores', () {
        final validKey = 'sk-proj-xoUa0YF4yXIEcVHE5eGsESFSG9EFq3tCl-N0ke6lkA';
        final result = validator.validateOpenAIKey(validKey);
        expect(result.isValid, true);
        expect(result.error, isNull);
      });

      test('should accept sk-svcacct- format key', () {
        final validKey = 'sk-svcacct-' + 'a1b2c3d4e5f6g7h8' * 3;
        final result = validator.validateOpenAIKey(validKey);
        expect(result.isValid, true);
        expect(result.error, isNull);
      });

      test('should accept long sk-proj- keys', () {
        final validKey = 'sk-proj-' + 'abcDEF012345_-' * 10;
        final result = validator.validateOpenAIKey(validKey);
        expect(result.isValid, true);
        expect(result.error, isNull);
      });

      test('should reject empty OpenAI API key', () {
        final result = validator.validateOpenAIKey('');
        expect(result.isValid, false);
        expect(result.error, contains('empty'));
      });

      test('should reject invalid OpenAI API key prefix', () {
        final result = validator.validateOpenAIKey('invalid-key');
        expect(result.isValid, false);
        expect(result.error, contains('sk-'));
      });

      test('should reject too short OpenAI API key', () {
        final result = validator.validateOpenAIKey('sk-short');
        expect(result.isValid, false);
      });

      test('should not accept Anthropic key as valid OpenAI key', () {
        final anthropicKey = 'sk-ant-' + 'a' * 95;
        final result = validator.validateOpenAIKey(anthropicKey);
        expect(result.isValid, false);
      });
    });

    group('Provider detection', () {
      test('should detect Anthropic provider', () {
        final validKey = 'sk-ant-' + 'a' * 95;
        final provider = validator.detectProvider(validKey);
        expect(provider, ApiProvider.anthropic);
      });

      test('should detect OpenAI provider', () {
        final validKey = 'sk-' + 'a' * 32;
        final provider = validator.detectProvider(validKey);
        expect(provider, ApiProvider.openai);
      });

      test('should detect OpenAI provider for sk-proj- key', () {
        final validKey = 'sk-proj-xoUa0YF4yXIEcVHE5eGsESFSG9EFq3tCl-N0ke6lkA';
        final provider = validator.detectProvider(validKey);
        expect(provider, ApiProvider.openai);
      });

      test('should not detect Anthropic key as OpenAI provider', () {
        // Short Anthropic-prefix key that fails _anthropicRegex but should NOT match _openaiRegex
        final shortAnthropicKey = 'sk-ant-' + 'a' * 30;
        final provider = validator.detectProvider(shortAnthropicKey);
        expect(provider, isNot(ApiProvider.openai));
      });

      test('should return null for invalid key', () {
        final provider = validator.detectProvider('invalid-key');
        expect(provider, isNull);
      });

      test('should return null for empty key', () {
        final provider = validator.detectProvider('');
        expect(provider, isNull);
      });
    });

    group('getKeyRequirements', () {
      test('should return requirements for Anthropic', () {
        final requirements = validator.getKeyRequirements(ApiProvider.anthropic);
        expect(requirements, contains('sk-ant-'));
        expect(requirements, contains('console.anthropic.com'));
      });

      test('should return requirements for OpenAI', () {
        final requirements = validator.getKeyRequirements(ApiProvider.openai);
        expect(requirements, contains('sk-'));
        expect(requirements, contains('platform.openai.com'));
      });
    });
  });
}
