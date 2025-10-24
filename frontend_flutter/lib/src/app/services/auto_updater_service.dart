import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:injectable/injectable.dart';
import 'package:flutter/foundation.dart';

/// Service for checking and managing application updates
@lazySingleton
class AutoUpdaterService {
  final Dio _dio;

  // GitHub repository info - update these with your actual repo
  static const String _owner = 'iliyaZelenko';
  static const String _repo = 'os-ai-computer-use';
  static const String _apiUrl = 'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  String? _currentVersion;
  String? _latestVersion;
  String? _downloadUrl;
  bool _updateAvailable = false;

  AutoUpdaterService(this._dio);

  /// Check if a new version is available
  Future<bool> checkForUpdates() async {
    try {
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      _currentVersion = packageInfo.version;

      // Fetch latest release from GitHub
      final response = await _dio.get(_apiUrl);

      if (response.statusCode == 200) {
        final data = response.data;
        _latestVersion = (data['tag_name'] as String).replaceAll('v', '');

        // Compare versions
        _updateAvailable = _isNewerVersion(_currentVersion!, _latestVersion!);

        if (_updateAvailable) {
          // Find appropriate asset for current platform
          _downloadUrl = _getDownloadUrlForPlatform(data['assets']);
          debugPrint('Update available: $_currentVersion -> $_latestVersion');
          debugPrint('Download URL: $_downloadUrl');
        }

        return _updateAvailable;
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }

    return false;
  }

  /// Get download URL for the current platform
  String? _getDownloadUrlForPlatform(List<dynamic> assets) {
    if (assets.isEmpty) return null;

    String platformPattern;
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      platformPattern = r'\.dmg$|\.app\.zip$|-macos\.';
    } else if (defaultTargetPlatform == TargetPlatform.windows) {
      platformPattern = r'\.exe$|\.msi$|-windows\.';
    } else if (defaultTargetPlatform == TargetPlatform.linux) {
      platformPattern = r'\.AppImage$|\.deb$|\.rpm$|-linux\.';
    } else {
      return null;
    }

    final regex = RegExp(platformPattern, caseSensitive: false);

    for (final asset in assets) {
      final name = asset['name'] as String;
      if (regex.hasMatch(name)) {
        return asset['browser_download_url'] as String;
      }
    }

    return null;
  }

  /// Compare semantic versions
  bool _isNewerVersion(String current, String latest) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final latestParts = latest.split('.').map(int.parse).toList();

      // Pad with zeros if needed
      while (currentParts.length < 3) currentParts.add(0);
      while (latestParts.length < 3) latestParts.add(0);

      for (int i = 0; i < 3; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }

      return false;
    } catch (e) {
      debugPrint('Error comparing versions: $e');
      return false;
    }
  }

  /// Open download URL in browser
  Future<void> downloadUpdate() async {
    if (_downloadUrl == null) {
      debugPrint('No download URL available');
      return;
    }

    try {
      final uri = Uri.parse(_downloadUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching download URL: $e');
    }
  }

  // Getters
  bool get updateAvailable => _updateAvailable;
  String? get currentVersion => _currentVersion;
  String? get latestVersion => _latestVersion;
  String? get downloadUrl => _downloadUrl;
}
