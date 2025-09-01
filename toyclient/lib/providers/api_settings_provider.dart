// lib/providers/app_settings_provider.dart

import 'package:flutter/material.dart';
import '../models/app_settings.dart';

/// A simple provider to manage the AppSettings.
class AppSettingsProvider with ChangeNotifier {
  AppSettings _settings = AppSettings(serverUrl: '');

  AppSettings get settings => _settings;

  /// Updates the server URL and notifies listeners.
  void setServerUrl(String newUrl) {
    if (_settings.serverUrl != newUrl) {
      _settings = AppSettings(serverUrl: newUrl);
      notifyListeners();
    }
  }
}
