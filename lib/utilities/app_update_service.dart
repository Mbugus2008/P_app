import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../models/app_version_info.dart';

class AppUpdateService extends GetxService {
  static const _channel = MethodChannel('com.trimline.parcel/installer');

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

      final client =
          HttpClient()..badCertificateCallback = (_, __, ___) => true;
      client.connectionTimeout = const Duration(seconds: 30);
      try {
        final req = await client.getUrl(
          Uri.parse('https://nav.trimline.co.ke:4013/api/AppUpdate/android'),
        );
        final resp = await req.close().timeout(const Duration(seconds: 20));

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

        lastCheckMessage.value = 'Downloading v$remoteVersion...';
        await _downloadApk();
        return 'update_found';
      } finally {
        client.close();
      }
    } catch (e) {
      final msg = '$e'.split('\n').first;
      lastCheckMessage.value = msg.length > 80 ? msg.substring(0, 80) : msg;
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
      lastCheckMessage.value = 'Starting download...';

      final dir = await getTemporaryDirectory();
      final apkDir = Directory(dir.path);
      if (!await apkDir.exists()) await apkDir.create(recursive: true);

      final apkPath = '${apkDir.path}/parcel_v${version.versionCode}.apk';
      final file = File(apkPath);

      // Check for partial file to resume
      var resumeAt = 0;
      if (await file.exists()) {
        final stat = await file.stat();
        // Verify the partial file starts with APK header
        if (stat.size >= 4) {
          final raf = await file.open(mode: FileMode.read);
          final header = await raf.read(4);
          await raf.close();
          if (header[0] == 0x50 &&
              header[1] == 0x4B &&
              header[2] == 0x03 &&
              header[3] == 0x04) {
            resumeAt = stat.size;
            final mb = resumeAt / (1024 * 1024);
            lastCheckMessage.value =
                'Resuming from ${mb.toStringAsFixed(1)} MB...';
            downloadProgress.value = 0.0; // will update relative to remaining
          } else {
            // Corrupted — delete and start fresh
            await file.delete();
          }
        } else {
          // Too small — delete and start fresh
          await file.delete();
        }
      }

      final client =
          HttpClient()..badCertificateCallback = (_, __, ___) => true;
      client.connectionTimeout = const Duration(seconds: 30);
      try {
        final req = await client.getUrl(Uri.parse(version.downloadUrl));
        if (resumeAt > 0) {
          req.headers.set(HttpHeaders.rangeHeader, 'bytes=$resumeAt-');
        }
        final resp = await req.close().timeout(const Duration(minutes: 5));

        final isResume = resp.statusCode == 206;
        if (resp.statusCode != 200 && resp.statusCode != 206) {
          lastCheckMessage.value = 'Download failed: HTTP ${resp.statusCode}';
          downloadProgress.value = -1;
          // Don't delete partial — keep it for retry
          return;
        }

        // If server responded 200 instead of 206, it ignored Range — restart
        if (resumeAt > 0 && !isResume) {
          await file.delete();
          resumeAt = 0;
          lastCheckMessage.value =
              'Server does not support resume. Restarting...';
        }

        final totalFromServer = resp.contentLength;
        final effectiveTotal =
            isResume
                ? resumeAt + (totalFromServer > 0 ? totalFromServer : 0)
                : totalFromServer;
        var received = resumeAt;

        // Open in append mode if resuming, otherwise overwrite
        final sink = file.openWrite(
          mode: resumeAt > 0 ? FileMode.append : FileMode.write,
        );
        final stopwatch = Stopwatch()..start();

        await for (final chunk in resp) {
          sink.add(chunk);
          received += chunk.length;

          if (effectiveTotal > 0) {
            downloadProgress.value = received / effectiveTotal;
            final pct = (received * 100 / effectiveTotal).toStringAsFixed(0);
            final mb = received / (1024 * 1024);
            lastCheckMessage.value =
                'Downloading... $pct% (${mb.toStringAsFixed(1)} MB)';
          } else {
            final mb = received / (1024 * 1024);
            lastCheckMessage.value =
                mb < 1
                    ? 'Downloading... ${(received / 1024).toStringAsFixed(0)} KB'
                    : 'Downloading... ${mb.toStringAsFixed(1)} MB';
          }
        }

        stopwatch.stop();
        await sink.flush();
        await sink.close();

        // ---- VERIFY the downloaded file ----
        final fileStat = await file.stat();
        final gotSize = fileStat.size;

        // Size check
        if (effectiveTotal > 0 && gotSize != effectiveTotal) {
          lastCheckMessage.value =
              'Download interrupted: got $gotSize of $effectiveTotal bytes (will resume)';
          downloadProgress.value = -1;
          // Keep the partial file for resuming
          return;
        }

        // APK magic bytes check
        if (gotSize < 4) {
          lastCheckMessage.value = 'Downloaded file too small';
          downloadProgress.value = -1;
          await file.delete();
          return;
        }
        final raf = await file.open(mode: FileMode.read);
        final header = await raf.read(4);
        await raf.close();
        if (header[0] != 0x50 ||
            header[1] != 0x4B ||
            header[2] != 0x03 ||
            header[3] != 0x04) {
          lastCheckMessage.value = 'Downloaded file is not a valid APK';
          downloadProgress.value = -1;
          await file.delete();
          return;
        }

        // ---- VERIFIED ----
        _downloadedApkPath = apkPath;
        downloadProgress.value = 1.0;
        updateReady.value = true;
        lastCheckMessage.value =
            'Download complete (${(gotSize / (1024 * 1024)).toStringAsFixed(1)} MB)';
      } finally {
        client.close();
      }
    } catch (e) {
      final msg = '$e'.split('\n').first;
      lastCheckMessage.value =
          'Download error: ${msg.length > 80 ? msg.substring(0, 80) : msg}';
      downloadProgress.value = -1;
      _downloadedApkPath = null;
      // Keep partial file for resume — don't delete on network errors
    } finally {
      isDownloading.value = false;
    }
  }

  String? get downloadedApkPath => _downloadedApkPath;

  /// Install silently using PackageInstaller (skips OpenFilex dialog)
  Future<bool> installSilent() async {
    final path = _downloadedApkPath;
    if (path == null) return false;
    final file = File(path);
    if (!await file.exists()) return false;

    try {
      await _channel.invokeMethod('installApkSilent', {'path': path});
      return true;
    } catch (e) {
      // Fallback to standard install
      try {
        await _channel.invokeMethod('installApk', {'path': path});
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  /// Standard install with system dialog
  Future<bool> installUpdate() async {
    final path = _downloadedApkPath;
    if (path == null) return false;
    final file = File(path);
    if (!await file.exists()) return false;

    try {
      await _channel.invokeMethod('installApk', {'path': path});
      return true;
    } catch (e) {
      return false;
    }
  }
}
