import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceIdHelper {
  static const _key = 'device_id';
  static DeviceIdHelper? _instance;
  String? _cached;

  DeviceIdHelper._();

  static DeviceIdHelper get instance {
    _instance ??= DeviceIdHelper._();
    return _instance!;
  }

  Future<String> getDeviceId() async {
    if (_cached != null) return _cached!;

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored != null && stored.isNotEmpty) {
      _cached = stored;
      return stored;
    }

    final generated = await _generateDeviceId();
    await prefs.setString(_key, generated);
    _cached = generated;
    return generated;
  }

  Future<String> _generateDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      String rawId;
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        rawId = info.id;
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        rawId = info.identifierForVendor ?? 'IOS-DEVICE';
      } else {
        rawId = 'UNKNOWN-DEVICE';
      }

      return rawId
          .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
          .substring(0, 12)
          .toUpperCase()
          .padRight(6, 'X');
    } catch (_) {
      return 'DEVICE-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase().substring(0, 6)}';
    }
  }
}
