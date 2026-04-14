import 'package:flutter/material.dart';
import 'package:word_puzzle/main.dart';

class ThemeNotifier extends ChangeNotifier {
  bool _isDarkMode = userPrefsBox.get('isDarkMode') ?? false;

  bool get isDarkMode => _isDarkMode;

  void toggleTheme(bool isOn) {
    _isDarkMode = isOn;
    userPrefsBox.put('isDarkMode', isOn);
    notifyListeners();
  }
}
