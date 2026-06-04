import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../models/app_version_info.dart';

/// Manages silent APK downloads and prompts user to install when ready.
/// Injected as a GetX service so the dashboard can listen to [downloadProgress].
class AppUpdateService extends GetxService {
  /// Observable download progress (0.0 to 1.0, -1 = idle, -2 = checking).
  final RxDouble downloadProgress = (-1.0).obs;

  /// True while a newer version is being downloaded.
  final RxBool isDownloading = false.obs;

  /// Set to true when a downloaded update is ready to install.
  final RxBool updateReady = false.obs;

  /// The downloaded APK file path (null until download completes).
  String? _downloadedApkPath;

  /// The version info for the pending install.
  AppVersionInfo? _pendingVersion;

  /// The base URL for API calls (same as ApiClient's baseUrl).
  String _baseUrl = 'https://nav.trimline.co.ke:4013';

  /// Timer for periodic checks (every 6 hours).
  Timer? _periodicCheckTimer;

  set baseUrl(String url) => _baseUrl = url;

  /// Call once at app start.
  Future<void> init() async {
    // Check immediately on startup (silent).
    await _checkForUpdate();

    // Then every 6 hours while the app runs.
    _periodicCheckTimer = Timer.periodic(
      const Duration(hours: 6),
      (_) => _checkForUpdate(),
    );
  }

  /// Checks the server for a newer version.
  /// If a newer version exists, starts silent download.
  Future<void> _checkForUpdate() async {
    try {
      downloadProgress.value = -2; // checking

      final uri = Uri.parse('$_baseUrl/api/AppUpdate/android');
      final response = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        downloadProgress.value = -1;
        return;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final envelope = ApiEnvelope<AppVersionInfo>.fromJson(
        decoded,
        (c) => AppVersionInfo.fromJson(c as Map<String, dynamic>),
      );

      if (!envelope.isSuccess || envelope.contents == null) {
        downloadProgress.value = -1;
        return;
      }

      final remote = envelope.contents!;

      // Skip if no download URL.
      if (remote.downloadUrl.isEmpty) {
        downloadProgress.value = -1;
        return;
      }

      final local = await PackageInfo.fromPlatform();
      final localVersionCode = int.tryParse(local.buildNumber) ?? 1;

      if (remote.versionCode <= localVersionCode) {
        // Already up to date.
        downloadProgress.value = -1;
        return;
      }

      // Newer version available — start silent download.
      await _downloadApk(remote);
    } catch (e) {
      if (kDebugMode) debugPrint('Update check failed: $e');
      downloadProgress.value = -1;
    }
  }

  /// Downloads the APK silently, updating [downloadProgress].
  Future<void> _downloadApk(AppVersionInfo version) async {
    try {
      isDownloading.value = true;
      updateReady.value = false;
      downloadProgress.value = 0.0;
      _pendingVersion = version;

      // Notify the user that a new version is downloading
      Get.snackbar(
        'Update Available',
        'Downloading v${version.version} (${version.versionCode})...',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 3),
        isDismissible: true,
      );

      final dir = await getApplicationDocumentsDirectory();
      final apkDir = Directory('${dir.path}/apk_downloads');
      if (!await apkDir.exists()) {
        await apkDir.create(recursive: true);
      }

      final filePath =
          '${apkDir.path}/parcel_update_v${version.versionCode}.apk';
      final file = File(filePath);

      // If already downloaded recently, skip re-download.
      if (await file.exists()) {
        final stat = await file.stat();
        if (DateTime.now().difference(stat.modified).inDays < 1) {
          _downloadedApkPath = filePath;
          downloadProgress.value = 1.0;
          updateReady.value = true;
          isDownloading.value = false;
          _pendingVersion = version;
          return;
        }
        // Otherwise delete stale file.
        await file.delete();
      }

      final uri = Uri.parse(version.downloadUrl);
      final client = http.Client();
      try {
        final request = http.Request('GET', uri);
        final response = await client.send(request);

        if (response.statusCode != 200) {
          throw HttpException(
            'Download failed: HTTP ${response.statusCode}',
            uri: uri,
          );
        }

        final totalBytes = response.contentLength ?? -1;
        var receivedBytes = 0;
        final sink = file.openWrite();

        await for (final chunk in response.stream) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          if (totalBytes > 0) {
            downloadProgress.value = receivedBytes / totalBytes;
          }
        }

        await sink.flush();
        await sink.close();

        _downloadedApkPath = filePath;
        downloadProgress.value = 1.0;
        updateReady.value = true;
      } finally {
        client.close();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('APK download failed: $e');
      downloadProgress.value = -1;
      _downloadedApkPath = null;
    } finally {
      isDownloading.value = false;
    }
  }

  /// Returns the path to the downloaded APK, if ready.
  String? get downloadedApkPath => _downloadedApkPath;

  /// Returns the pending version info.
  AppVersionInfo? get pendingVersion => _pendingVersion;

  /// Call when user accepts the update — triggers Android install intent.
  Future<void> installUpdate(BuildContext context) async {
    final path = _downloadedApkPath;
    if (path == null) return;

    final file = File(path);
    if (!await file.exists()) return;

    try {
      // Use the standard MethodChannel to invoke the Android installer.
      const channel = MethodChannel('com.trimline.parcel/installer');
      await channel.invokeMethod('installApk', {'path': path});
    } catch (e) {
      if (kDebugMode) debugPrint('Install via channel failed: $e');
      // Fallback: show a message with the file location.
      if (context.mounted) {
        Get.snackbar(
          'Download Complete',
          'Open the file manager and install:\n$path',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 10),
        );
      }
    }
  }

  /// Cleans up old APK files (keep only the latest).
  Future<void> cleanOldApks() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final apkDir = Directory('${dir.path}/apk_downloads');
      if (!await apkDir.exists()) return;

      final files = await apkDir.list().toList();
      files.sort((a, b) => b.path.compareTo(a.path));
      for (var i = 1; i < files.length; i++) {
        await files[i].delete();
      }
    } catch (_) {}
  }

  @override
  void onClose() {
    _periodicCheckTimer?.cancel();
    super.onClose();
  }
}
