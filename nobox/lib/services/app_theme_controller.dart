import 'package:flutter/material.dart';
import 'app_preferences.dart';

/// Controller tema global (Gelap / Terang) untuk NoBox Chat
class AppThemeController extends ChangeNotifier {
  static final AppThemeController instance = AppThemeController._internal();
  AppThemeController._internal();

  static const String _themePrefKey = 'app_is_dark_mode';
  bool _isDark = true;

  bool get isDarkMode => _isDark;

  Future<void> init() async {
    final saved = await AppPreferences.getBool(_themePrefKey);
    if (saved != null) {
      _isDark = saved;
      notifyListeners();
    }
  }

  void toggleTheme() {
    _isDark = !_isDark;
    AppPreferences.setBool(_themePrefKey, _isDark);
    notifyListeners();
  }

  void setDarkMode(bool isDark) {
    if (_isDark != isDark) {
      _isDark = isDark;
      AppPreferences.setBool(_themePrefKey, _isDark);
      notifyListeners();
    }
  }
}
