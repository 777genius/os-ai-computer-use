import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
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
  late TextEditingController _preferencesController;
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
    _preferencesController = TextEditingController(text: config.userPreferences ?? '');
    _loadSavedKeys();
  }

  Future<void> _loadSavedKeys() async {
    setState(() => _isLoading = true);
    try {
      final keys = await _storage.getAllApiKeys();
      final savedProvider = await _storage.getActiveProvider();
      final savedPreferences = await _storage.getUserPreferences();
      if (!mounted) return;
      setState(() {
        _anthropicKey = keys['anthropic'] ?? '';
        _openaiKey = keys['openai'] ?? '';
        if (savedProvider != null) {
          _activeProvider = savedProvider;
        } else {
          _autoDetectProvider();
        }
        if (savedPreferences != null) {
          _preferencesController.text = savedPreferences;
        }
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
    _preferencesController.dispose();
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
      } else {
        await _storage.deleteAnthropicApiKey();
      }
      if (_openaiKey.isNotEmpty) {
        await _storage.saveOpenAIApiKey(_openaiKey);
      } else {
        await _storage.deleteOpenAIApiKey();
      }
      await _storage.saveActiveProvider(_activeProvider);

      // Save user preferences
      final prefs = _preferencesController.text.trim();
      if (prefs.isNotEmpty) {
        await _storage.saveUserPreferences(prefs);
      } else {
        await _storage.deleteUserPreferences();
      }

      // Mark setup as complete
      await _storage.markSetupComplete();

      if (!mounted) return;

      // Update app config
      final config = context.read<AppConfig>();
      config.update(
        host: _hostController.text,
        port: int.tryParse(_portController.text),
        anthropicApiKey: _anthropicKey,
        openaiApiKey: _openaiKey,
        activeProvider: _activeProvider,
        userPreferences: prefs.isEmpty ? '' : prefs,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Settings saved successfully'),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          duration: const Duration(seconds: 2),
        ),
      );

      // Return to previous screen
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving settings: $e'),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
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
    final isMacOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Settings',
          style: TextStyle(color: colorScheme.onSurface),
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        automaticallyImplyLeading: !isMacOS,
        leadingWidth: isMacOS ? 100.0 : null,
        leading: isMacOS
            ? Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              )
            : null,
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
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          children: [
            _constrained(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
            // Personal Preferences Section
            _buildSectionHeader('Personal Preferences', Icons.tune),
            const SizedBox(height: 8),
            Card(
              color: colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Describe how you want the AI to respond and behave. '
                      'These preferences will be included in every prompt.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _preferencesController,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Your preferences',
                        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                        hintText: 'e.g. Always respond in Russian, be concise, use code examples...',
                        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: colorScheme.outline),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: colorScheme.outline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: colorScheme.primary, width: 2),
                        ),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 5,
                      minLines: 3,
                      maxLength: 2000,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

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

            // Permissions (macOS)
            if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) ...[
              _buildSectionHeader('Permissions', Icons.security),
              const SizedBox(height: 8),
              const _PermissionsSection(),
              const SizedBox(height: 32),
            ],

            // Save Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveSettings,
              icon: const Icon(Icons.save),
              label: const Text('Save Settings'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                textStyle: const TextStyle(fontSize: 16),
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                disabledBackgroundColor: colorScheme.surfaceContainerHighest,
                disabledForegroundColor: colorScheme.onSurface.withValues(alpha: 0.38),
              ),
            ),

            const SizedBox(height: 16),

            // Security Notice
            _buildSecurityNotice(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _constrained({required Widget child}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 24, color: colorScheme.onSurface),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildHelpCard(String title, List<Widget> children) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.primaryContainer,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: false,
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
        childrenPadding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
        iconColor: colorScheme.onPrimaryContainer,
        collapsedIconColor: colorScheme.onPrimaryContainer,
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkItem(String text, String url, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _launchUrl(url),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            Icon(icon, size: 16, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                color: colorScheme.primary,
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
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'anthropic',
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Anthropic (Claude)'),
                      const SizedBox(width: 6),
                      if (hasAnthropic)
                        Icon(Icons.check_circle, color: colorScheme.primary, size: 16)
                      else
                        Icon(Icons.warning_amber, color: colorScheme.error, size: 16),
                    ],
                  ),
                  icon: const Icon(Icons.auto_awesome),
                ),
                ButtonSegment(
                  value: 'openai',
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('OpenAI (GPT)'),
                      const SizedBox(width: 6),
                      if (hasOpenai)
                        Icon(Icons.check_circle, color: colorScheme.primary, size: 16)
                      else
                        Icon(Icons.warning_amber, color: colorScheme.error, size: 16),
                    ],
                  ),
                  icon: const Icon(Icons.bolt),
                ),
              ],
              selected: {_activeProvider},
              onSelectionChanged: (v) => setState(() => _activeProvider = v.first),
            ),
            if ((_activeProvider == 'anthropic' && !hasAnthropic) ||
                (_activeProvider == 'openai' && !hasOpenai))
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Please enter the API key for the selected provider above.',
                  style: TextStyle(color: colorScheme.error, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSection() {
    final colorScheme = Theme.of(context).colorScheme;
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
            style: TextStyle(color: colorScheme.onSurface),
            decoration: InputDecoration(
              labelText: 'Backend Host',
              labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: colorScheme.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: colorScheme.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
              hintText: '127.0.0.1',
              hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
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
            style: TextStyle(color: colorScheme.onSurface),
            decoration: InputDecoration(
              labelText: 'Backend Port',
              labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: colorScheme.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: colorScheme.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
              hintText: '8765',
              hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
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
          const SizedBox(height: 16),
          _CheckConnectionButton(
            hostController: _hostController,
            portController: _portController,
          ),
        ],
      ],
    );
  }

  Widget _buildSecurityNotice() {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.lock, color: colorScheme.onTertiaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Your API keys are encrypted (AES-256) and stored locally on your device.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onTertiaryContainer,
                ),
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

class _CheckConnectionButton extends StatefulWidget {
  final TextEditingController hostController;
  final TextEditingController portController;
  const _CheckConnectionButton({required this.hostController, required this.portController});

  @override
  State<_CheckConnectionButton> createState() => _CheckConnectionButtonState();
}

class _CheckConnectionButtonState extends State<_CheckConnectionButton> {
  bool _checking = false;
  String? _result;
  bool? _success;

  Future<void> _check() async {
    setState(() { _checking = true; _result = null; _success = null; });
    final host = widget.hostController.text.trim().isEmpty ? '127.0.0.1' : widget.hostController.text.trim();
    final port = widget.portController.text.trim().isEmpty ? '8765' : widget.portController.text.trim();
    final url = 'http://$host:$port/healthz';

    try {
      final response = await Dio().get(
        url,
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );
      if (response.statusCode == 200) {
        setState(() { _result = 'Connected'; _success = true; });
      } else {
        setState(() { _result = 'Status ${response.statusCode}'; _success = false; });
      }
    } catch (e) {
      setState(() { _result = 'Connection failed'; _success = false; });
    } finally {
      setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = const Color(0xFF66BB6A);
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: _checking ? null : _check,
          icon: _checking
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.wifi_find, size: 18),
          label: const Text('Check Connection'),
          style: OutlinedButton.styleFrom(
            foregroundColor: colorScheme.onSurface,
            side: BorderSide(color: colorScheme.outline),
          ),
        ),
        if (_result != null) ...[
          const SizedBox(width: 12),
          Icon(
            _success == true ? Icons.check_circle : Icons.error,
            size: 18,
            color: _success == true ? successColor : colorScheme.error,
          ),
          const SizedBox(width: 4),
          Text(
            _result!,
            style: TextStyle(
              fontSize: 13,
              color: _success == true ? successColor : colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}

class _PermissionsSection extends StatefulWidget {
  const _PermissionsSection();

  @override
  State<_PermissionsSection> createState() => _PermissionsSectionState();
}

class _PermissionsSectionState extends State<_PermissionsSection> {
  static const _channel = MethodChannel('com.osai/permissions');

  bool? _accessibility;
  bool? _screenRecording;
  bool? _inputMonitoring;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkAll();
  }

  Future<void> _checkAll() async {
    setState(() => _loading = true);
    try {
      final a = await _channel.invokeMethod<bool>('checkAccessibility');
      final s = await _channel.invokeMethod<bool>('checkScreenRecording');
      final i = await _channel.invokeMethod<bool>('checkInputMonitoring');
      if (!mounted) return;
      setState(() {
        _accessibility = a ?? false;
        _screenRecording = s ?? false;
        _inputMonitoring = i ?? false;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Permissions check error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _request(String method) async {
    try {
      await _channel.invokeMethod(method);
    } catch (_) {}
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) _checkAll();
  }

  int get _grantedCount =>
      [_accessibility, _screenRecording, _inputMonitoring].where((v) => v == true).length;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final allGranted = _grantedCount == 3;

    if (_loading) {
      return Card(
        color: colorScheme.surfaceContainerLow,
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    return Card(
      color: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: allGranted
                    ? const Color(0xFF66BB6A).withValues(alpha: 0.1)
                    : colorScheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    allGranted ? Icons.check_circle : Icons.warning_amber_rounded,
                    size: 18,
                    color: allGranted ? const Color(0xFF66BB6A) : colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      allGranted
                          ? 'All permissions granted'
                          : '$_grantedCount of 3 permissions granted — some features may not work',
                      style: TextStyle(
                        fontSize: 12,
                        color: allGranted ? const Color(0xFF66BB6A) : colorScheme.error,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Re-check permissions',
                    onPressed: _checkAll,
                    icon: Icon(Icons.refresh, size: 16, color: colorScheme.onSurfaceVariant),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _PermissionRow(
              icon: Icons.accessibility_new,
              name: 'Accessibility',
              description: 'Control mouse and keyboard for automation',
              granted: _accessibility,
              onRequest: () => _request('requestAccessibility'),
              required: true,
            ),
            const SizedBox(height: 8),
            _PermissionRow(
              icon: Icons.screenshot_monitor,
              name: 'Screen Recording',
              description: 'Capture screenshots so AI can see your screen',
              granted: _screenRecording,
              onRequest: () => _request('requestScreenRecording'),
              required: true,
            ),
            const SizedBox(height: 8),
            _PermissionRow(
              icon: Icons.keyboard,
              name: 'Input Monitoring',
              description: 'Emergency stop hotkey Ctrl+Esc from any app',
              granted: _inputMonitoring,
              onRequest: () => _request('requestInputMonitoring'),
              required: false,
            ),
            if (!allGranted) ...[
              const SizedBox(height: 12),
              Text(
                'After granting, you may need to restart the app for changes to take effect.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  fontStyle: FontStyle.italic,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final IconData icon;
  final String name;
  final String description;
  final bool? granted;
  final VoidCallback onRequest;
  final bool required;

  const _PermissionRow({
    required this.icon,
    required this.name,
    required this.description,
    required this.granted,
    required this.onRequest,
    this.required = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isGranted = granted == true;
    final statusColor = isGranted ? const Color(0xFF66BB6A) : colorScheme.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isGranted
              ? const Color(0xFF66BB6A).withValues(alpha: 0.3)
              : colorScheme.error.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          // Status icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: statusColor),
          ),
          const SizedBox(width: 12),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    )),
                    if (!this.required) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('Optional', style: TextStyle(
                          fontSize: 9,
                          color: colorScheme.onSurfaceVariant,
                        )),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(description, style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 11,
                )),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Status badge + action
          if (isGranted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF66BB6A).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check, size: 12, color: Color(0xFF66BB6A)),
                  const SizedBox(width: 4),
                  const Text('Granted', style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF66BB6A),
                  )),
                ],
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: onRequest,
              icon: const Icon(Icons.open_in_new, size: 14),
              label: const Text('Grant'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                textStyle: const TextStyle(fontSize: 12),
                side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.5)),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }
}
