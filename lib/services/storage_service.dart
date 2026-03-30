import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Session storage simulation (just prefixing keys)
  static Future<void> setSessionValue(String key, String value) async {
    await _prefs.setString('session_$key', value);
  }

  static String? getSessionValue(String key) {
    return _prefs.getString('session_$key');
  }

  static Future<void> removeSessionValue(String key) async {
    await _prefs.remove('session_$key');
  }

  // Local storage simulation
  static Future<void> setLocalValue(String key, String value) async {
    await _prefs.setString('local_$key', value);
  }

  static String? getLocalValue(String key) {
    return _prefs.getString('local_$key');
  }

  static Future<void> removeLocalValue(String key) async {
    await _prefs.remove('local_$key');
  }

  // Cookies simulation
  static Future<void> setCookie(String key, String value) async {
    await _prefs.setString('cookie_$key', value);
  }

  static String? getCookie(String key) {
    return _prefs.getString('cookie_$key');
  }

  static Future<void> removeCookie(String key) async {
    await _prefs.remove('cookie_$key');
  }

  static Future<void> clearAll() async {
    await _prefs.clear();
  }
  
  // Add these methods for web localStorage (optional)
  static void setWebLocalStorage(String key, String value) {
    // This is just a wrapper - your existing setLocalValue works fine
    setLocalValue(key, value);
  }
  
  static String? getWebLocalStorage(String key) {
    return getLocalValue(key);
  }
}