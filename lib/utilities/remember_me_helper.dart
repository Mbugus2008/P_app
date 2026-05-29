import 'package:shared_preferences/shared_preferences.dart';

class RememberMeHelper {
  static const String _keyIdentifier = 'remembered_identifier';
  static const String _keyRememberMe = 'remember_me_enabled';

  static Future<void> saveRememberedUser(String identifier) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyIdentifier, identifier);
    await prefs.setBool(_keyRememberMe, true);
  }

  static Future<void> clearRememberedUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIdentifier);
    await prefs.setBool(_keyRememberMe, false);
  }

  static Future<String?> getRememberedIdentifier() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyIdentifier);
  }

  static Future<bool> isRememberMeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyRememberMe) ?? false;
  }
}
