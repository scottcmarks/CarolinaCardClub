// app_settings_provider.dart
import 'package:flutter/material.dart';
import 'app_settings.dart'; // Import your AppSettings class

class AppSettingsProvider extends ChangeNotifier {
  AppSettings _currentSettings = const AppSettings(); // Initialize with default settings

  AppSettings get currentSettings => _currentSettings;

  void updateSettings({
    bool? showOnlyActiveSessions,
    TimeOfDay? defaultStartTime,
    String? preferredTheme,
  }) {
    // Use copyWith to create a new AppSettings instance with the updated values
    _currentSettings = _currentSettings.copyWith(
      showOnlyActiveSessions: showOnlyActiveSessions,
      defaultStartTime: defaultStartTime,
      preferredTheme: preferredTheme,
    );
    notifyListeners(); // Notify all listening widgets
  }

  // You can also have individual update methods for clarity if you prefer
  void setShowOnlyActiveSessions(bool newValue) {
    if (_currentSettings.showOnlyActiveSessions != newValue) {
      _currentSettings = _currentSettings.copyWith(showOnlyActiveSessions: newValue);
      notifyListeners();
    }
  }

  void setDefaultStartTime(TimeOfDay newTime) {
    if (_currentSettings.defaultStartTime != newTime) {
      _currentSettings = _currentSettings.copyWith(defaultStartTime: newTime);
      notifyListeners();
    }
  }

  void setPreferredTheme(String newTheme) {
    if (_currentSettings.preferredTheme != newTheme) {
      _currentSettings = _currentSettings.copyWith(preferredTheme: newTheme);
      notifyListeners();
    }
  }
}
