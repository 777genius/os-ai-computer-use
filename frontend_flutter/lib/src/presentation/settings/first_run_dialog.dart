import 'package:flutter/material.dart';
import 'package:frontend_flutter/src/app/config/app_config.dart';
import 'package:frontend_flutter/src/app/services/api_key_validator.dart';
import 'package:frontend_flutter/src/app/services/secure_storage_service.dart';
import 'package:frontend_flutter/src/presentation/settings/widgets/api_key_field.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class FirstRunDialog extends StatefulWidget {
  const FirstRunDialog({super.key});

  @override
  State<FirstRunDialog> createState() => _FirstRunDialogState();
}

class _FirstRunDialogState extends State<FirstRunDialog> {
  final _formKey = GlobalKey<FormState>();
  final _storage = GetIt.I<SecureStorageService>();
  String _selectedProvider = 'openai';
  String _anthropicKey = '';
  String _openaiKey = '';
  bool _isLoading = false;

  String get _activeKey => _selectedProvider == 'openai' ? _openaiKey : _anthropicKey;

  Future<void> _getStarted() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_anthropicKey.isNotEmpty) {
        await _storage.saveAnthropicApiKey(_anthropicKey);
      }
      if (_openaiKey.isNotEmpty) {
        await _storage.saveOpenAIApiKey(_openaiKey);
      }
      await _storage.saveActiveProvider(_selectedProvider);
      await _storage.markSetupComplete();

      if (!mounted) return;
      final config = context.read<AppConfig>();
      config.update(
        anthropicApiKey: _anthropicKey.isEmpty ? null : _anthropicKey,
        openaiApiKey: _openaiKey.isEmpty ? null : _openaiKey,
        activeProvider: _selectedProvider,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving API key: $e'), backgroundColor: Theme.of(context).colorScheme.errorContainer),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAnthropic = _selectedProvider == 'anthropic';

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.smart_toy, size: 64, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),

                Text(
                  'Welcome to OS AI',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose your AI provider and enter the API key',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Provider selector
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'anthropic', label: Text('Anthropic'), icon: Icon(Icons.auto_awesome)),
                    ButtonSegment(value: 'openai', label: Text('OpenAI'), icon: Icon(Icons.bolt)),
                  ],
                  selected: {_selectedProvider},
                  onSelectionChanged: (v) => setState(() => _selectedProvider = v.first),
                ),
                const SizedBox(height: 24),

                // Info card — changes based on provider
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    initiallyExpanded: false,
                    shape: const Border(),
                    collapsedShape: const Border(),
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
                    childrenPadding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                    iconColor: Theme.of(context).colorScheme.onPrimaryContainer,
                    collapsedIconColor: Theme.of(context).colorScheme.onPrimaryContainer,
                    title: Text(
                      'Need an API key?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAnthropic ? '1. Visit console.anthropic.com' : '1. Visit platform.openai.com',
                              style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
                            ),
                            Text('2. Sign up or log in', style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer)),
                            Text('3. Create a new API key', style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer)),
                            Text('4. Copy and paste it below', style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer)),
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: () => _launchUrl(
                                isAnthropic
                                    ? 'https://console.anthropic.com/'
                                    : 'https://platform.openai.com/api-keys',
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.launch, size: 16, color: Theme.of(context).colorScheme.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    isAnthropic ? 'Open Anthropic Console' : 'Open OpenAI Platform',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.primary,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // API key field — for selected provider
                if (isAnthropic)
                  ApiKeyField(
                    label: 'Anthropic API Key',
                    hint: 'sk-ant-...',
                    provider: ApiProvider.anthropic,
                    required: true,
                    onChanged: (value) => _anthropicKey = value,
                  )
                else
                  ApiKeyField(
                    label: 'OpenAI API Key',
                    hint: 'sk-...',
                    provider: ApiProvider.openai,
                    required: true,
                    onChanged: (value) => _openaiKey = value,
                  ),
                const SizedBox(height: 24),

                // Security notice
                Row(
                  children: [
                    Icon(Icons.lock, size: 16, color: Theme.of(context).colorScheme.primary),
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

                ElevatedButton(
                  onPressed: _isLoading ? null : _getStarted,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Get Started'),
                ),
                const SizedBox(height: 12),

                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
                  child: const Text('Skip for now'),
                ),
              ],
            ),
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
