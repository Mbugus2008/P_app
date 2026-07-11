import 'dart:ffi' show Abi;

/// Detects the device CPU ABI and returns the matching APK URL.
/// Falls back to the universal APK if ABI can't be determined.
String detectAbiApkUrl(String baseUrl) {
  try {
    final abi = Abi.current().toString();
    final base = baseUrl.replaceAll('ParcelApp.apk', '');
    if (abi.contains('arm64') || abi.contains('aarch64')) {
      return '${base}app-arm64-v8a-release.apk';
    }
    if (abi.contains('armeabi') || abi.contains('arm')) {
      return '${base}app-armeabi-v7a-release.apk';
    }
    if (abi.contains('x86_64') || abi.contains('amd64')) {
      return '${base}app-x86_64-release.apk';
    }
  } catch (_) {}
  return baseUrl;
}
