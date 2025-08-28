// client/lib/providers/app_settings_provider.dart

import 'package:flutter/material.dart';
import '../models/app_settings.dart';

class AppSettingsProvider with ChangeNotifier {
  AppSettings _currentSettings = AppSettings(
    localServerUrl: 'http://localhost:8080', // New default
    localServerApiKey: '9af85ab7895eb6d8baceb0fe1203c96851c87bdbad9af5fd5d5d0de2a24dad428b5906722412bfa5b4fe3a9a07a7a24abea50cff4c9de08c02b8708871f1c2b1', // Default key
    defaultSessionStartTime: const TimeOfDay(hour: 19, minute: 30),
  );

  AppSettings get currentSettings => _currentSettings;

  void updateSettings(AppSettings newSettings) {
    _currentSettings = newSettings;
    notifyListeners();
  }

  // Helper method for toggling active sessions
  void setShowOnlyActiveSessions(bool value) {
    if (_currentSettings.showOnlyActiveSessions != value) {
      _currentSettings = _currentSettings.copyWith(showOnlyActiveSessions: value);
      notifyListeners();
    }
  }
}
