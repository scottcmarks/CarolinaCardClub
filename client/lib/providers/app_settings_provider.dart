import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared/shared.dart';

import '../models/app_settings.dart';

class AppSettingsProvider with ChangeNotifier {
  // Initialize with default values to prevent LateInitializationError during startup.
  late AppSettings _currentSettings;
  late SharedPreferences _prefs;

  // Flag to indicate when settings have been loaded from storage. This is
  // crucial for the ApiProvider to know when it's safe to act on setting changes.
  bool isInitialized = false;

  // Public getter for the UI to access the current settings.
  AppSettings get currentSettings => _currentSettings;

  // The constructor is now clean and synchronous.
  AppSettingsProvider() {
    // Initialize with defaults immediately. The real values will be loaded
    // asynchronously by the loadSettings() method.
    _currentSettings = AppSettings.defaults();
  }

  /// Loads settings from the device's persistent storage.
  /// This should be called once at app startup before runApp().
  Future<void> loadSettings() async {
    try {
      _prefs = await SharedPreferences.getInstance();

      // Read each setting from storage, providing a default value if not found.
      final serverUrl = _prefs.getString('localServerUrl') ?? defaultServerUrl;
      final apiKey = _prefs.getString('localServerApiKey') ?? localApiKey; // From shared package
      final theme = _prefs.getString('preferredTheme') ?? defaultTheme;
      final sessionHour = _prefs.getInt('sessionHour') ?? defaultSessionHour;
      final sessionMinute = _prefs.getInt('sessionMinute') ?? defaultSessionMinute;

      _currentSettings = AppSettings(
        localServerUrl: serverUrl,
        localServerApiKey: apiKey,
        preferredTheme: theme,
        defaultSessionStartTime: TimeOfDay(hour: sessionHour, minute: sessionMinute),
      );

      // Mark as initialized once real data is loaded.
      isInitialized = true;

      // No need to notify listeners here; this is called before the UI is built.

    } catch (e) {
      print('Failed to load settings: $e');
      // In a real app, you might want more sophisticated error handling here.
    }
  }

  /// Saves the current settings to the device's persistent storage.
  Future<void> _saveSettings() async {
    await _prefs.setString('localServerUrl', _currentSettings.localServerUrl);
    await _prefs.setString('localServerApiKey', _currentSettings.localServerApiKey);
    await _prefs.setString('preferredTheme', _currentSettings.preferredTheme);
    if (_currentSettings.defaultSessionStartTime != null) {
      await _prefs.setInt('sessionHour', _currentSettings.defaultSessionStartTime!.hour);
      await _prefs.setInt('sessionMinute', _currentSettings.defaultSessionStartTime!.minute);
    }
  }

  /// Updates the in-memory settings, persists the changes, and notifies listeners.
  /// This is the method that the settings UI should call.
  void updateSettings(AppSettings newSettings) {
    _currentSettings = newSettings;
    // Notify listeners so that other parts of the app (like the UI theme and
    // the ApiProvider) can react to the change.
    notifyListeners();
    // Save the new settings to the device for the next app launch.
    _saveSettings();
  }
}
