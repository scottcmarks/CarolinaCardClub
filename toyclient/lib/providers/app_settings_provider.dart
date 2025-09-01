// lib/providers/app_settings_provider.dart

import 'package:flutter/material.dart';
import '../models/app_settings.dart';

/// A provider to manage the AppSettings.
class AppSettingsProvider with ChangeNotifier {
  // The provider now correctly initializes its state using the defaults from the model.
  AppSettings _settings = AppSettings.defaults();

  AppSettings get settings => _settings;

  /// Updates the server URL, preserves the API key, and notifies listeners.
  void setServerUrl(String newUrl) {
    if (_settings.serverUrl != newUrl) {
      // This now matches the AppSettings constructor.
      _settings = AppSettings(serverUrl: newUrl, apiKey: _settings.apiKey);
      notifyListeners();
    }
  }
}
