import 'package:injectable/injectable.dart';

/// Provider types supported by the application
enum ApiProvider {
  anthropic,
  openai,
}

/// Result of API key validation
class ValidationResult {
  final bool isValid;
  final String? error;

  const ValidationResult({required this.isValid, this.error});

  factory ValidationResult.valid() => const ValidationResult(isValid: true);
  factory ValidationResult.invalid(String error) =>
      ValidationResult(isValid: false, error: error);
}

/// Service for validating API keys format
@lazySingleton
class ApiKeyValidator {
  // Anthropic API keys start with sk-ant- and contain specific characters
  static final _anthropicRegex = RegExp(r'^sk-ant-[a-zA-Z0-9_-]{95,}$');

  // OpenAI API keys start with sk- and contain specific characters
  static final _openaiRegex = RegExp(r'^sk-[a-zA-Z0-9]{32,}$');

  /// Validate any API key and determine its provider
  ValidationResult validate(String apiKey, {ApiProvider? expectedProvider}) {
    if (apiKey.isEmpty) {
      return ValidationResult.invalid('API key cannot be empty');
    }

    if (apiKey.length < 20) {
      return ValidationResult.invalid('API key is too short');
    }

    // If expected provider is specified, validate against that provider only
    if (expectedProvider != null) {
      return _validateForProvider(apiKey, expectedProvider);
    }

    // Otherwise, try to detect the provider
    if (_anthropicRegex.hasMatch(apiKey)) {
      return ValidationResult.valid();
    } else if (_openaiRegex.hasMatch(apiKey)) {
      return ValidationResult.valid();
    } else if (apiKey.startsWith('sk-ant-')) {
      return ValidationResult.invalid(
          'Invalid Anthropic API key format. Please check your key.');
    } else if (apiKey.startsWith('sk-')) {
      return ValidationResult.invalid(
          'Invalid OpenAI API key format. Please check your key.');
    } else {
      return ValidationResult.invalid(
          'Unrecognized API key format. Keys should start with "sk-"');
    }
  }

  /// Validate Anthropic API key
  ValidationResult validateAnthropicKey(String apiKey) {
    return _validateForProvider(apiKey, ApiProvider.anthropic);
  }

  /// Validate OpenAI API key
  ValidationResult validateOpenAIKey(String apiKey) {
    return _validateForProvider(apiKey, ApiProvider.openai);
  }

  ValidationResult _validateForProvider(
      String apiKey, ApiProvider provider) {
    if (apiKey.isEmpty) {
      return ValidationResult.invalid('API key cannot be empty');
    }

    switch (provider) {
      case ApiProvider.anthropic:
        if (!apiKey.startsWith('sk-ant-')) {
          return ValidationResult.invalid(
              'Anthropic API keys must start with "sk-ant-"');
        }
        if (!_anthropicRegex.hasMatch(apiKey)) {
          return ValidationResult.invalid(
              'Invalid Anthropic API key format. Key should be at least 100 characters long.');
        }
        return ValidationResult.valid();

      case ApiProvider.openai:
        if (!apiKey.startsWith('sk-')) {
          return ValidationResult.invalid(
              'OpenAI API keys must start with "sk-"');
        }
        if (!_openaiRegex.hasMatch(apiKey)) {
          return ValidationResult.invalid(
              'Invalid OpenAI API key format. Please check your key.');
        }
        return ValidationResult.valid();
    }
  }

  /// Detect which provider an API key belongs to
  ApiProvider? detectProvider(String apiKey) {
    if (_anthropicRegex.hasMatch(apiKey)) {
      return ApiProvider.anthropic;
    } else if (_openaiRegex.hasMatch(apiKey)) {
      return ApiProvider.openai;
    }
    return null;
  }

  /// Get a user-friendly message about key requirements
  String getKeyRequirements(ApiProvider provider) {
    switch (provider) {
      case ApiProvider.anthropic:
        return 'Anthropic API keys start with "sk-ant-" and are about 100 characters long. '
            'Get your key from https://console.anthropic.com/';
      case ApiProvider.openai:
        return 'OpenAI API keys start with "sk-" and are about 50 characters long. '
            'Get your key from https://platform.openai.com/api-keys';
    }
  }
}
