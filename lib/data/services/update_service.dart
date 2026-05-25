import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Self-update service: checks a hosted version manifest, downloads new APK,
/// and opens the system installer.
class UpdateService {
  UpdateService._();

  static final UpdateService _instance = UpdateService._();
  static UpdateService get instance => _instance;

  /// URL of the version manifest JSON file.
  /// Update this file on GitHub when you release a new APK.
  static const String _versionUrl =
      'https://raw.githubusercontent.com/sansan69/CycleZen-Mobile/main/version.json';

  // ── Public state ──

  bool _checking = false;
  bool get isChecking => _checking;

  // ── Version check ──

  /// Check if an update is available. Returns [UpdateInfo] or null.
  Future<UpdateInfo?> checkForUpdate() async {
    if (_checking) return null;
    _checking = true;

    try {
      final response = await http
          .get(Uri.parse(_versionUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('Update check failed: HTTP ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final remoteVersionCode = data['versionCode'] as int? ?? 0;
      final remoteVersion = data['version'] as String? ?? '0.0.0';
      final apkUrl = data['apkUrl'] as String?;
      final changelog = data['changelog'] as String? ?? '';
      final mandatory = data['mandatory'] as bool? ?? false;

      if (apkUrl == null || apkUrl.isEmpty) {
        debugPrint('Update check: no apkUrl in manifest');
        return null;
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 0;
      final currentVersion = packageInfo.version;

      debugPrint(
          'Update check: current=$currentVersion ($currentVersionCode), '
          'remote=$remoteVersion ($remoteVersionCode)');

      if (remoteVersionCode > currentVersionCode) {
        return UpdateInfo(
          version: remoteVersion,
          versionCode: remoteVersionCode,
          currentVersion: currentVersion,
          apkUrl: apkUrl,
          changelog: changelog,
          mandatory: mandatory,
        );
      }

      return null; // up to date
    } catch (e) {
      debugPrint('Update check error: $e');
      return null;
    } finally {
      _checking = false;
    }
  }

  // ── Download ──

  /// Download the APK and return the local file path.
  /// Reports progress via [onProgress] (0.0 → 1.0).
  Future<String> downloadApk(
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getExternalStorageDirectory();
    if (dir == null) throw Exception('No external storage available');

    final file = File('${dir.path}/cyclezen_update.apk');
    if (await file.exists()) await file.delete();

    final request = http.Request('GET', Uri.parse(url));
    final streamedResponse = await http.Client().send(request);
    final totalBytes = streamedResponse.contentLength ?? 0;

    if (streamedResponse.statusCode != 200) {
      throw Exception('Download failed: HTTP ${streamedResponse.statusCode}');
    }

    var downloadedBytes = 0;
    final sink = file.openWrite();

    await for (final chunk in streamedResponse.stream) {
      sink.add(chunk);
      downloadedBytes += chunk.length;
      if (totalBytes > 0 && onProgress != null) {
        onProgress(downloadedBytes / totalBytes);
      }
    }

    await sink.flush();
    await sink.close();

    return file.path;
  }

  /// Open the APK file with the system package installer.
  Future<void> installApk(String filePath) async {
    await OpenFilex.open(filePath, type: 'application/vnd.android.package-archive');
  }
}

/// Parsed update information from the remote manifest.
class UpdateInfo {
  final String version;
  final int versionCode;
  final String currentVersion;
  final String apkUrl;
  final String changelog;
  final bool mandatory;

  const UpdateInfo({
    required this.version,
    required this.versionCode,
    required this.currentVersion,
    required this.apkUrl,
    required this.changelog,
    required this.mandatory,
  });
}
