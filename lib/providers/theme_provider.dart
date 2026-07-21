import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  static const String _themePrefKey = 'theme_mode';
  static const String _seedColorPrefKey = 'seed_color';

  // Default teal seed matching the redesign's M3 teal scheme.
  static const Color defaultSeedColor = Color(0xFF00696B);

  static const List<Color> accentSwatches = [
    defaultSeedColor,
    Color(0xFF2E5AAC), // blue
    Color(0xFF6E55A8), // purple
    Color(0xFFAD4E70), // pink
    Color(0xFF8A5A00), // amber
    Color(0xFF4C662B), // green
  ];

  ThemeMode _themeMode = ThemeMode.system;
  Color _seedColor = defaultSeedColor;

  ThemeMode get themeMode => _themeMode;
  Color get seedColor => _seedColor;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();

    // Load Mode
    final String? themeStr = prefs.getString(_themePrefKey);
    if (themeStr != null) {
      if (themeStr == 'light') _themeMode = ThemeMode.light;
      if (themeStr == 'dark') _themeMode = ThemeMode.dark;
      if (themeStr == 'system') _themeMode = ThemeMode.system;
    }

    final int? seedValue = prefs.getInt(_seedColorPrefKey);
    if (seedValue != null) {
      _seedColor = Color(seedValue);
    }

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    String themeStr = 'system';
    if (mode == ThemeMode.light) themeStr = 'light';
    if (mode == ThemeMode.dark) themeStr = 'dark';
    await prefs.setString(_themePrefKey, themeStr);
  }

  Future<void> setSeedColor(Color color) async {
    _seedColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_seedColorPrefKey, color.toARGB32());
  }
}
