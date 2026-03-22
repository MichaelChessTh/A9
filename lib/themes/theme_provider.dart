import 'package:flutter/material.dart';
import 'package:googlechat/services/cache/local_cache.dart';
import 'package:googlechat/themes/dark_mode.dart';
import 'package:googlechat/themes/light_mode.dart';

class ThemeProvider extends ChangeNotifier {
  // Start with the persisted theme or system theme
  ThemeData _themeData;

  ThemeProvider() : _themeData = _initialTheme();

  static ThemeData _initialTheme() {
    // Check local cache first
    final persistedIsDark = LocalCache.getIsDarkMode();
    if (persistedIsDark != null) {
      return persistedIsDark ? darkMode : lightMode;
    }
    // Fallback to system theme
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final isDark = brightness == Brightness.dark;
    return isDark ? darkMode : lightMode;
  }

  ThemeData get themeData => _themeData;
  bool get isDarkMode => _themeData == darkMode;

  set themeData(ThemeData themeData) {
    _themeData = themeData;
    final isDark = themeData == darkMode;
    LocalCache.setIsDarkMode(isDark);
    notifyListeners();
  }

  void toggleTheme() {
    if (_themeData == lightMode) {
      themeData = darkMode;
    } else {
      themeData = lightMode;
    }
  }
}
