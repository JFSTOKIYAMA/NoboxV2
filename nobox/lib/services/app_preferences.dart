import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Penyimpanan preferensi lokal yang aman dan tahan gangguan (fail-safe).
/// Memiliki fallback in-memory cache jika platform channel atau R8
/// belum siap atau melempar exception di lingkungan rilis/tes.
class AppPreferences {
  static final Map<String, dynamic> _memoryCache = {};

  static Future<String?> getString(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getString(key);
      if (val != null) {
        _memoryCache[key] = val;
        return val;
      }
    } catch (e) {
      debugPrint('AppPreferences: getString fallback to memory for key "$key": $e');
    }
    return _memoryCache[key] as String?;
  }

  static Future<bool?> getBool(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getBool(key);
      if (val != null) {
        _memoryCache[key] = val;
        return val;
      }
    } catch (e) {
      debugPrint('AppPreferences: getBool fallback to memory for key "$key": $e');
    }
    return _memoryCache[key] as bool?;
  }

  static Future<void> setString(String key, String value) async {
    _memoryCache[key] = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (e) {
      debugPrint('AppPreferences: setString saved in memory only for key "$key": $e');
    }
  }

  static Future<void> setBool(String key, bool value) async {
    _memoryCache[key] = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (e) {
      debugPrint('AppPreferences: setBool saved in memory only for key "$key": $e');
    }
  }

  static Future<void> remove(String key) async {
    _memoryCache.remove(key);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (e) {
      debugPrint('AppPreferences: remove error for key "$key": $e');
    }
  }
}
