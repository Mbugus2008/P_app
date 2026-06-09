import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../models/app_version_info.dart';

class AppUpdateService extends GetxService {
  final RxDouble downloadProgress = (-1.0).obs;
  final RxBool isDownloading = false.obs;
  final RxBool updateReady = false.obs;
  final RxString lastCheckMessage = ''.obs;

  String? _downloadedApkPath;
  AppVersionInfo? pendingVersion;
  Timer? _timer;

  @override
  void onInit() {
    super.onInit();
    _check();
    _timer = Timer.periodic(const Duration(hours: 6), (_) => _check());
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }

  Future<String> checkForUpdate() => _check();

  Future<String> _check() async {
    try {
      downloadProgress.value = -2;

      final local = await PackageInfo.fromPlatform();
      final localCode = int.tryParse(local.buildNumber) ?? 0;

      final client = HttpClient()
        ..badCertificateCallback = (_, __, ___) => true;
      try {
        final req = await client
            .getUrl(Uri.parse('https://nav.trimline.co.ke:4013/api/AppUpdate/android'));
        final resp = await req.close().timeout(const Duration(seconds: 15));

        if (resp.statusCode != 200) {
          lastCheckMessage.value = 'HTTP ${resp.statusCode}';
          downloadProgress.value = -1;
          return 'error';
        }

        final body = await resp.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final c = json['contents'] as Map<String, dynamic>?;

        if (c == null) {
          lastCheckMessage.value = 'Bad response';
          downloadProgress.value = -1;
          return 'error';
        }

        final remoteVersion = c['version'] as String? ?? '?';
        final remoteCode = (c['versionCode'] as num?)?.toInt() ?? 0;
        final downloadUrl = c['downloadUrl'] as String? ?? '';

        lastCheckMessage.value = 'Local #$localCode — Server #$remoteCode';

        if (remoteCode <= localCode || downloadUrl.isEmpty) {
          downloadProgress.value = -1;
          return 'up_to_date';
        }

        pendingVersion = AppVersionInfo(
          version: remoteVersion,
          versionCode: remoteCode,
          buildDate: c['buildDate'] as String? ?? '',
          downloadUrl: downloadUrl,
          releaseNotes: c['releaseNotes'] as String?,
          forceUpdate: c['forceUpdate'] as bool? ?? false,
        );

        await _downloadApk();
        return 'update_found';
      } finally {
        client.close();
      }
    } catch (e) {
      lastCheckMessage.value = '$e'.split('\n').first;
      downloadProgress.value = -1;
      return 'error';
    }
  }

  Future<void> _downloadApk() async {
    final version = pendingVersion;
    if (version == null) return;

    try {
      isDownloading.value = true;
      updateReady.value = false;
      downloadProgress.value = 0.0;

      final dir = await getApplicationDocumentsDirectory();
      final apkDir = Directory('${dir.path}/apk_downloads');
      if (!await apkDir.exists()) await apkDir.create(recursive: true);

      final filePath = '${apkDir.path}/parcel_v${version.versionCode}.apk';
      final file = File(filePath);

      if (await file.exists()) {
        final stat = await file.stat();
        if (DateTime.now().difference(stat.modified).inHours < 1) {
          _downloadedApkPath = filePath;
          downloadProgress.value = 1.0;
          updateReady.value = true;
          isDownloading.value = false;
          return;
        }
        await file.delete();
      }

      final client = HttpClient()
        ..badCertificateCallback = (_, __, ___) => true;
      try {
        final req = await client.getUrl(Uri.parse(version.downloadUrl));
        final resp = await req.close();

        if (resp.statusCode != 200) {
          downloadProgress.value = -1;
          return;
        }

        final total = resp.contentLength;
        var received = 0;
        final sink = file.openWrite();

        await for (final chunk in resp) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) downloadProgress.value = received / total;
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
          SnackBar(content: Text('APK at: $path')),
        );
      }
    }
  }
}
