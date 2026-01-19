import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Enum cho các tùy chọn theme
enum AppThemeMode {
  system, // Theo hệ thống
  light, // Sáng
  dark, // Tối
}

/// Provider quản lý theme của toàn bộ app
class ThemeProvider extends ChangeNotifier {
  static const String _themePrefKey = 'theme_mode';

  AppThemeMode _themeMode = AppThemeMode.system;
  bool _isInitialized = false;

  AppThemeMode get themeMode => _themeMode;
  bool get isInitialized => _isInitialized;

  /// Get actual ThemeMode for MaterialApp
  ThemeMode get materialThemeMode {
    switch (_themeMode) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }

  /// Initialize theme from SharedPreferences
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeModeString = prefs.getString(_themePrefKey);

      if (themeModeString != null) {
        _themeMode = AppThemeMode.values.firstWhere(
          (e) => e.toString() == themeModeString,
          orElse: () => AppThemeMode.system,
        );
      } else {
        _themeMode = AppThemeMode.system;
      }

      _isInitialized = true;
      notifyListeners();
      debugPrint('✅ Theme loaded: $_themeMode');
    } catch (e) {
      debugPrint('❌ Error loading theme: $e');
      _themeMode = AppThemeMode.system;
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Set theme mode and save to SharedPreferences
  Future<void> setThemeMode(AppThemeMode mode) async {
    if (_themeMode == mode) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themePrefKey, mode.toString());

      _themeMode = mode;
      notifyListeners();
      debugPrint('✅ Theme changed to: $mode');
    } catch (e) {
      debugPrint('❌ Error saving theme: $e');
      rethrow;
    }
  }

  /// Get display name for theme mode
  static String getThemeModeDisplayName(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return 'Theo hệ thống';
      case AppThemeMode.light:
        return 'Sáng';
      case AppThemeMode.dark:
        return 'Tối';
    }
  }

  /// Get icon for theme mode
  static IconData getThemeModeIcon(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return Icons.brightness_auto;
      case AppThemeMode.light:
        return Icons.brightness_5;
      case AppThemeMode.dark:
        return Icons.brightness_3;
    }
  }
}
