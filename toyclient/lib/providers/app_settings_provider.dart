// lib/providers/app_settings_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import 'package:shared/shared.dart';

/// A provider to manage AppSettings, with persistence to device storage.
class AppSettingsProvider with ChangeNotifier {
  static const _serverUrlKey = 'serverUrl';

  late AppSettings _currentSettings;
  bool _isLoading = true;

  // Public getters to match your architecture
  AppSettings get currentSettings => _currentSettings;
  bool get isLoading => _isLoading;

  /// Constructor immediately triggers loading settings from storage.
  AppSettingsProvider() {
    loadSettings();
  }

  /// Loads settings from SharedPreferences and initializes the provider's state.
  Future<void> loadSettings() async {
    _isLoading = true;
    // We don't notify at the start, to avoid a flicker on app start.

    final prefs = await SharedPreferences.getInstance();
    // Load the saved server URL, defaulting to an empty string.
    final serverUrl = prefs.getString(_serverUrlKey) ?? defaultServerUrl;

    _currentSettings = AppSettings.defaults().copyWith(serverUrl: serverUrl);
    _isLoading = false;
    notifyListeners(); // Notify that loading is complete and UI can be built.
  }

  /// Saves the current settings to SharedPreferences.
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, _currentSettings.serverUrl);
  }

  /// Updates the application settings, persists them, and notifies listeners.
  Future<void> updateSettings(AppSettings newSettings) async {
    if (_currentSettings.serverUrl != newSettings.serverUrl) {
      _currentSettings = newSettings;
      notifyListeners();
      await _saveSettings();
    }
  }
}
