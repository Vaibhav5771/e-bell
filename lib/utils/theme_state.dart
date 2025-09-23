import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  Color _selectedColor = Colors.orange; // Default color
  static const String _colorKey = 'selected_theme_color';

  ThemeProvider() {
    _loadColor();
  }

  Color get selectedColor => _selectedColor;

  Color get textColor => _selectedColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;

  void setColor(Color color) async {
    _selectedColor = color;
    notifyListeners();
    await _saveColor(color);
  }

  Future<void> _loadColor() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt(_colorKey);
    if (colorValue != null) {
      _selectedColor = Color(colorValue);
      notifyListeners();
    }
  }

  Future<void> _saveColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_colorKey, color.value);
  }
}