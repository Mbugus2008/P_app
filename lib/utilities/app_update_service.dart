import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../models/app_version_info.dart';

class AppUpdateService extends GetxService {
  final RxDouble downloadProgress = (-1.0).obs;
  final RxBool isDownloading = false.obs;
  final RxBool updateReady = false.obs;

  String? _downloadedApkPath;
  AppVersionInfo? _pendingVersion;
  String _baseUrl = 'https://nav.trimline.co.ke:4013';
  Timer? _periodicCheckTimer;

  set baseUrl(String url) => _baseUrl = url;

  Future<void> init() async {
    await _checkForUpdate();
    _periodicCheckTimer = Timer.periodic(
      const Duration(hours: 6),
      (_) => _checkForUpdate(),
    );
  }

  /// Public method so the user can manually trigger an update check.
  Future<void> checkForUpdate() async {
    await _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    try {
      downloadProgress.value = -2; // shows checking bar on dashboard

      final local = await PackageInfo.fromPlatform();
      final localCode = int.tryParse(local.buildNumber) ?? 1;

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
      if (remote.downloadUrl.isEmpty || remote.versionCode <= localCode) {
        downloadProgress.value = -1;
        return;
      }

      // Start download
      await _downloadApk(remote);
    } catch (e) {
      downloadProgress.value = -1;
    }
  }

  Future<void> _downloadApk(AppVersionInfo version) async {
    try {
      isDownloading.value = true;
      updateReady.value = false;
      downloadProgress.value = 0.0;
      _pendingVersion = version;

      final dir = await getApplicationDocumentsDirectory();
      final apkDir = Directory('${dir.path}/apk_downloads');
      if (!await apkDir.exists()) await apkDir.create(recursive: true);

      final filePath =
          '${apkDir.path}/parcel_update_v${version.versionCode}.apk';
      final file = File(filePath);

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
      downloadProgress.value = -1;
      _downloadedApkPath = null;
    } finally {
      isDownloading.value = false;
    }
  }

  String? get downloadedApkPath => _downloadedApkPath;
  AppVersionInfo? get pendingVersion => _pendingVersion;

  Future<void> installUpdate(BuildContext context) async {
    final path = _downloadedApkPath;
    if (path == null) return;

    final file = File(path);
    if (!await file.exists()) return;

    try {
      const channel = MethodChannel('com.trimline.parcel/installer');
      await channel.invokeMethod('installApk', {'path': path});
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('APK downloaded to: $path'),
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }
  }

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
