import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

class PasswordCrypto {
  static const String _scheme = 'sha256';

  static String hashPassword(String password) {
    final cleanPassword = password.trim();
    if (cleanPassword.isEmpty) return '';

    final saltBytes = List<int>.generate(
      16,
      (_) => Random.secure().nextInt(256),
    );
    final salt = base64Encode(saltBytes);
    final hash = _hashWithSalt(cleanPassword, salt);
    return '$_scheme\$$salt\$$hash';
  }

  static bool isHashedPassword(String value) {
    final cleanValue = value.trim();
    if (!cleanValue.startsWith('$_scheme\$')) return false;

    final parts = cleanValue.split('\$');
    return parts.length == 3 && parts[1].isNotEmpty && parts[2].isNotEmpty;
  }

  static String hashIfNeeded(String value) {
    final cleanValue = value.trim();
    if (cleanValue.isEmpty || isHashedPassword(cleanValue)) return cleanValue;
    return hashPassword(cleanValue);
  }

  static bool verifyPassword({
    required String password,
    required String storedPassword,
  }) {
    final cleanPassword = password.trim();
    final cleanStored = storedPassword.trim();

    if (cleanStored.isEmpty || cleanPassword.isEmpty) return false;

    if (!isHashedPassword(cleanStored)) {
      return cleanPassword == cleanStored;
    }

    final parts = cleanStored.split('\$');
    final salt = parts[1];
    final expectedHash = parts[2];
    final actualHash = _hashWithSalt(cleanPassword, salt);

    return _constantTimeEquals(actualHash, expectedHash);
  }

  static String _hashWithSalt(String password, String salt) {
    final bytes = utf8.encode('$salt:$password');
    return sha256.convert(bytes).toString();
  }

  static bool _constantTimeEquals(String left, String right) {
    if (left.length != right.length) return false;
    var result = 0;
    for (var i = 0; i < left.length; i++) {
      result |= left.codeUnitAt(i) ^ right.codeUnitAt(i);
    }
    return result == 0;
  }
}
