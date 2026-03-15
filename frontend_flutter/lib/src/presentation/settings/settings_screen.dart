import 'package:flutter/material.dart';
import 'package:frontend_flutter/src/app/config/app_config.dart';
import 'package:frontend_flutter/src/app/services/api_key_validator.dart';
import 'package:frontend_flutter/src/app/services/secure_storage_service.dart';
import 'package:frontend_flutter/src/presentation/settings/widgets/api_key_field.dart';
import 'package:provider/provider.dart';
import 'package:get_it/get_it.dart';
import 'package:url_launcher/url_launcher.dart';

/// Settings screen for configuring API keys and backend connection
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storage = GetIt.I<SecureStorageService>();

  late TextEditingController _hostController;
  late TextEditingController _portController;
  String _anthropicKey = '';
  String _openaiKey = '';
  String _activeProvider = 'anthropic';

  bool _isLoading = false;
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    final config = context.read<AppConfig>();
    _hostController = TextEditingController(text: config.host);
    _portController = TextEditingController(text: config.port.toString());
    _loadSavedKeys();
  }

  Future<void> _loadSavedKeys() async {
    setState(() => _isLoading = true);
    try {
      final keys = await _storage.getAllApiKeys();
      final savedProvider = await _storage.getActiveProvider();
      setState(() {
        _anthropicKey = keys['anthropic'] ?? '';
        _openaiKey = keys['openai'] ?? '';
        if (savedProvider != null) {
          _activeProvider = savedProvider;
        } else {
          _autoDetectProvider();
        }
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _autoDetectProvider() {
    if (_openaiKey.isNotEmpty && _anthropicKey.isEmpty) {
      _activeProvider = 'openai';
    } else {
      _activeProvider = 'anthropic';
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Save API keys to secure storage
      if (_anthropicKey.isNotEmpty) {
        await _storage.saveAnthropicApiKey(_anthropicKey);
      }
      if (_openaiKey.isNotEmpty) {
        await _storage.saveOpenAIApiKey(_openaiKey);
      }
      await _storage.saveActiveProvider(_activeProvider);

      // Mark setup as complete
      await _storage.markSetupComplete();

      // Update app config
      final config = context.read<AppConfig>();
      config.update(
        host: _hostController.text,
        port: int.tryParse(_portController.text),
        anthropicApiKey: _anthropicKey.isEmpty ? null : _anthropicKey,
        openaiApiKey: _openaiKey.isEmpty ? null : _openaiKey,
        activeProvider: _activeProvider,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Return to previous screen
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving settings: $e'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // API Keys Section
            _buildSectionHeader('API Keys', Icons.key),
            const SizedBox(height: 8),
            _buildHelpCard(
              'Get your API keys:',
              [
                _buildLinkItem(
                  'Anthropic Console',
                  'https://console.anthropic.com/',
                  Icons.launch,
                ),
                _buildLinkItem(
                  'OpenAI Platform',
                  'https://platform.openai.com/api-keys',
                  Icons.launch,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Anthropic API Key
            ApiKeyField(
              label: 'Anthropic API Key',
              hint: 'sk-ant-...',
              initialValue: _anthropicKey,
              provider: ApiProvider.anthropic,
              required: _activeProvider == 'anthropic',
              onChanged: (value) => _anthropicKey = value,
            ),
            const SizedBox(height: 16),

            // OpenAI API Key
            ApiKeyField(
              label: 'OpenAI API Key',
              hint: 'sk-...',
              initialValue: _openaiKey,
              provider: ApiProvider.openai,
              required: _activeProvider == 'openai',
              onChanged: (value) => _openaiKey = value,
            ),
            const SizedBox(height: 24),

            // Provider Selector
            _buildSectionHeader('Active Provider', Icons.smart_toy),
            const SizedBox(height: 8),
            _buildProviderSelector(),
            const SizedBox(height: 32),

            // Advanced Settings
            _buildAdvancedSection(),

            const SizedBox(height: 32),

            // Save Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveSettings,
              icon: const Icon(Icons.save),
              label: const Text('Save Settings'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),

            const SizedBox(height: 16),

            // Security Notice
            _buildSecurityNotice(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    );
  }

  Widget _buildHelpCard(String title, List<Widget> children) {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildLinkItem(String text, String url, IconData icon) {
    return InkWell(
      onTap: () => _launchUrl(url),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.blue),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderSelector() {
    final hasAnthropic = _anthropicKey.isNotEmpty;
    final hasOpenai = _openaiKey.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: _activeProvider,
              decoration: const InputDecoration(
                labelText: 'AI Provider',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.smart_toy),
              ),
              items: [
                DropdownMenuItem(
                  value: 'anthropic',
                  child: Row(
                    children: [
                      const Text('Anthropic (Claude)'),
                      const SizedBox(width: 8),
                      if (hasAnthropic)
                        const Icon(Icons.check_circle, color: Colors.green, size: 16)
                      else
                        const Icon(Icons.warning_amber, color: Colors.orange, size: 16),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'openai',
                  child: Row(
                    children: [
                      const Text('OpenAI (GPT-5.4)'),
                      const SizedBox(width: 8),
                      if (hasOpenai)
                        const Icon(Icons.check_circle, color: Colors.green, size: 16)
                      else
                        const Icon(Icons.warning_amber, color: Colors.orange, size: 16),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _activeProvider = value);
                }
              },
            ),
            if ((_activeProvider == 'anthropic' && !hasAnthropic) ||
                (_activeProvider == 'openai' && !hasOpenai))
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Please enter the API key for the selected provider above.',
                  style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () => setState(() => _showAdvanced = !_showAdvanced),
          icon: Icon(_showAdvanced ? Icons.expand_less : Icons.expand_more),
          label: const Text('Advanced Settings'),
        ),
        if (_showAdvanced) ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _hostController,
            decoration: const InputDecoration(
              labelText: 'Backend Host',
              border: OutlineInputBorder(),
              hintText: '127.0.0.1',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Host is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _portController,
            decoration: const InputDecoration(
              labelText: 'Backend Port',
              border: OutlineInputBorder(),
              hintText: '8765',
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Port is required';
              }
              final port = int.tryParse(value);
              if (port == null || port < 1 || port > 65535) {
                return 'Invalid port number';
              }
              return null;
            },
          ),
        ],
      ],
    );
  }

  Widget _buildSecurityNotice() {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.lock, color: Colors.green),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Your API keys are securely stored in your system keychain and never leave your device.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
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
