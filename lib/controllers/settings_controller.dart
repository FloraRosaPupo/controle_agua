import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class SettingsController {
  String userName = "Gabriel Silva";
  String planName = "PLANO HYDRA PRO";

  bool dailyReminders = true;
  bool vibration = true;

  double dailyGoal = 2500;
  double minGoal = 1000;
  double maxGoal = 5000;

  bool get isDarkMode => AppTheme.themeMode.value == ThemeMode.dark;
  String unitOfMeasure = "Mililitros (ml)";
  String get visualTheme => isDarkMode ? "Neon Dark" : "Luminoso";

  void toggleTheme(bool value) {
    AppTheme.themeMode.value = value ? ThemeMode.dark : ThemeMode.light;
  }

  void toggleReminders(bool value) {
    dailyReminders = value;
  }

  void toggleVibration(bool value) {
    vibration = value;
  }

  void updateGoal(double value) {
    dailyGoal = value;
  }
}
