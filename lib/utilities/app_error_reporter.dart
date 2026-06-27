import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/parcel_controller.dart';

class AppErrorReporter {
  static final AppErrorReporter instance = AppErrorReporter._();
  AppErrorReporter._();

  String? _deviceId;
  String? _appVersion;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _deviceId = prefs.getString('device_id');
      final info = await PackageInfo.fromPlatform();
      _appVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {}
  }

  /// Report an error to the API.
  Future<void> report(dynamic error, StackTrace? stack) async {
    try {
      String? user, location;
      try {
        final controller = Get.find<ParcelController>();
        user = controller.loggedInUser?.agentCode;
        location = controller.currentLocation;
      } catch (_) {
        // Controller not available yet — that's fine
      }

      final client = HttpClient();
      client.badCertificateCallback = (_, __, ___) => true;
      client.connectionTimeout = const Duration(seconds: 10);

      final request = await client.postUrl(
        Uri.parse('https://nav.trimline.co.ke:4013/api/errors/report'),
      );
      request.headers.contentType = ContentType.json;

      final body = jsonEncode({
        'deviceId': _deviceId ?? 'unknown',
        'user': user ?? 'unknown',
        'location': location ?? 'unknown',
        'appVersion': _appVersion ?? 'unknown',
        'error': '$error',
        'stackTrace': '$stack',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      });

      request.write(body);
      final response = await request.close();
      await response.drain();
      client.close();
    } catch (_) {
      // Silently ignore — don't cause error loop
    }
  }

  /// Register global Flutter error handler.
  void setupGlobalHandler() {
    FlutterError.onError = (details) {
      // Log to console in debug
      FlutterError.presentError(details);
      // Report to API
      report(details.exceptionAsString(), details.stack);
    };

    // Catch unhandled async errors
    PlatformDispatcher.instance.onError = (error, stack) {
      report(error, stack);
      return true; // handled
    };
  }
}
