import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend_flutter/src/app/services/api_key_validator.dart';

/// Reusable widget for API key input with validation
class ApiKeyField extends StatefulWidget {
  final String label;
  final String? hint;
  final String? initialValue;
  final ApiProvider provider;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final bool required;

  const ApiKeyField({
    super.key,
    required this.label,
    this.hint,
    this.initialValue,
    required this.provider,
    this.onChanged,
    this.validator,
    this.required = true,
  });

  @override
  State<ApiKeyField> createState() => _ApiKeyFieldState();
}

class _ApiKeyFieldState extends State<ApiKeyField> {
  late TextEditingController _controller;
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      obscureText: _obscureText,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint ?? _getDefaultHint(),
        border: const OutlineInputBorder(),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Toggle visibility button
            IconButton(
              icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
              onPressed: () {
                setState(() {
                  _obscureText = !_obscureText;
                });
              },
              tooltip: _obscureText ? 'Show key' : 'Hide key',
            ),
            // Copy button
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: _controller.text.isEmpty
                  ? null
                  : () {
                      Clipboard.setData(ClipboardData(text: _controller.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('API key copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
              tooltip: 'Copy key',
            ),
            // Paste button
            IconButton(
              icon: const Icon(Icons.paste),
              onPressed: () async {
                final data = await Clipboard.getData('text/plain');
                if (data?.text != null) {
                  _controller.text = data!.text!;
                  widget.onChanged?.call(data.text!);
                }
              },
              tooltip: 'Paste key',
            ),
          ],
        ),
      ),
      validator: widget.validator ??
          (value) {
            if (!widget.required && (value == null || value.isEmpty)) {
              return null;
            }

            if (widget.required && (value == null || value.isEmpty)) {
              return 'API key is required';
            }

            final validator = ApiKeyValidator();
            final result = validator.validateForProvider(value!, widget.provider);

            return result.isValid ? null : result.error;
          },
      onChanged: widget.onChanged,
      maxLines: 1,
      autocorrect: false,
      enableSuggestions: false,
    );
  }

  String _getDefaultHint() {
    switch (widget.provider) {
      case ApiProvider.anthropic:
        return 'sk-ant-...';
      case ApiProvider.openai:
        return 'sk-...';
    }
  }
}

extension on ApiKeyValidator {
  ValidationResult validateForProvider(String value, ApiProvider provider) {
    switch (provider) {
      case ApiProvider.anthropic:
        return validateAnthropicKey(value);
      case ApiProvider.openai:
        return validateOpenAIKey(value);
    }
  }
}
