import 'package:flutter/material.dart';
import 'package:frontend_flutter/src/app/config/app_config.dart';
import 'package:frontend_flutter/src/app/services/api_key_validator.dart';
import 'package:frontend_flutter/src/app/services/secure_storage_service.dart';
import 'package:frontend_flutter/src/presentation/settings/widgets/api_key_field.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Dialog shown on first launch to collect API key
class FirstRunDialog extends StatefulWidget {
  const FirstRunDialog({super.key});

  @override
  State<FirstRunDialog> createState() => _FirstRunDialogState();
}

class _FirstRunDialogState extends State<FirstRunDialog> {
  final _formKey = GlobalKey<FormState>();
  final _storage = GetIt.I<SecureStorageService>();
  String _anthropicKey = '';
  bool _isLoading = false;

  Future<void> _getStarted() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Save API key to secure storage
      await _storage.saveAnthropicApiKey(_anthropicKey);

      // Mark setup as complete
      await _storage.markSetupComplete();

      // Update app config
      if (!mounted) return;
      final config = context.read<AppConfig>();
      config.update(anthropicApiKey: _anthropicKey);

      if (!mounted) return;

      // Close dialog
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving API key: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo/Icon
              const Icon(
                Icons.smart_toy,
                size: 64,
                color: Colors.blue,
              ),
              const SizedBox(height: 16),

              // Welcome text
              Text(
                'Welcome to OS AI',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'To get started, please enter your Anthropic API key',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Info card
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Need an API key?',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text('1. Visit console.anthropic.com'),
                      const Text('2. Sign up or log in'),
                      const Text('3. Create a new API key'),
                      const Text('4. Copy and paste it below'),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () => _launchUrl('https://console.anthropic.com/'),
                        child: const Row(
                          children: [
                            Icon(Icons.launch, size: 16, color: Colors.blue),
                            SizedBox(width: 4),
                            Text(
                              'Open Anthropic Console',
                              style: TextStyle(
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // API Key field
              ApiKeyField(
                label: 'Anthropic API Key',
                hint: 'sk-ant-...',
                provider: ApiProvider.anthropic,
                required: true,
                onChanged: (value) => _anthropicKey = value,
              ),
              const SizedBox(height: 24),

              // Security notice
              Row(
                children: [
                  const Icon(Icons.lock, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your API key is stored securely in your system keychain',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Get Started button
              ElevatedButton(
                onPressed: _isLoading ? null : _getStarted,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  textStyle: const TextStyle(fontSize: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Get Started'),
              ),
              const SizedBox(height: 12),

              // Skip button (optional - allows user to set up later)
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        Navigator.of(context).pop(false);
                      },
                child: const Text('Skip for now'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
