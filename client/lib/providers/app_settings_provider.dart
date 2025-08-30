// client/lib/providers/app_settings_provider.dart

import 'package:flutter/material.dart';
import '../models/app_settings.dart';
// Import the shared package to get the API key
import 'package:shared/shared.dart';

class AppSettingsProvider with ChangeNotifier {
  AppSettings _currentSettings = AppSettings(
    localServerUrl: 'http://127.0.0.1:8080', // Use explicit IP for localhost
    // Use the imported constant for the default key
    localServerApiKey: localApiKey,
    defaultSessionStartTime: const TimeOfDay(hour: 19, minute: 30),
  );

  AppSettings get currentSettings => _currentSettings;

  void updateSettings(AppSettings newSettings) {
    _currentSettings = newSettings;
    notifyListeners();
  }

  void setShowOnlyActiveSessions(bool value) {
    if (_currentSettings.showOnlyActiveSessions != value) {
      _currentSettings = _currentSettings.copyWith(showOnlyActiveSessions: value);
      notifyListeners();
    }
  }
}
