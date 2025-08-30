// client/lib/providers/app_settings_provider.dart

import 'package:flutter/material.dart';
import 'package:shared/shared.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

class AppSettingsProvider with ChangeNotifier {
  // Initialize with default values to prevent LateInitializationError.
  AppSettings _currentSettings = AppSettings.defaults();
  late SharedPreferences _prefs;
  // Use a flag to indicate if settings have been loaded from storage.
  bool isInitialized = false;

  AppSettings get currentSettings => _currentSettings;

  AppSettingsProvider();

  Future<void> loadSettings() async {
    try {
      _prefs = await SharedPreferences.getInstance();

      final serverUrl =
          _prefs.getString('localServerUrl') ?? 'http://127.0.0.1:8080';
      final apiKey =
          _prefs.getString('localServerApiKey') ?? localApiKey; // From shared
      final theme = _prefs.getString('preferredTheme') ?? 'light';
      final sessionHour = _prefs.getInt('sessionHour') ?? 19;
      final sessionMinute = _prefs.getInt('sessionMinute') ?? 30;

      _currentSettings = AppSettings(
        localServerUrl: serverUrl,
        localServerApiKey: apiKey,
        preferredTheme: theme,
        defaultSessionStartTime:
            TimeOfDay(hour: sessionHour, minute: sessionMinute),
      );

      // Mark as initialized once real data is loaded.
      isInitialized = true;
    } catch (e) {
      print('Failed to load settings: $e');
      throw e;
    }
  }

  Future<void> _saveSettings() async {
    await _prefs.setString('localServerUrl', _currentSettings.localServerUrl);
    await _prefs.setString(
        'localServerApiKey', _currentSettings.localServerApiKey);
    await _prefs.setString('preferredTheme', _currentSettings.preferredTheme);
    if (_currentSettings.defaultSessionStartTime != null) {
      await _prefs.setInt(
          'sessionHour', _currentSettings.defaultSessionStartTime!.hour);
      await _prefs.setInt(
          'sessionMinute', _currentSettings.defaultSessionStartTime!.minute);
    }
  }

  void updateSettings(AppSettings newSettings) {
    _currentSettings = newSettings;
    notifyListeners();
    _saveSettings();
  }
}