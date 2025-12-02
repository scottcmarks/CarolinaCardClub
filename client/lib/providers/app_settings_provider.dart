// client/lib/providers/app_settings_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared/shared.dart';

import '../models/app_settings.dart';

class AppSettingsProvider with ChangeNotifier {
  late SharedPreferences _prefs;
  late AppSettings _currentSettings;

  // Use a Future to signal when initialization is complete
  late Future<void> _initFuture;

  AppSettings get currentSettings => _currentSettings;
  Future<void> get initializationComplete => _initFuture;

  AppSettingsProvider() {
    _currentSettings = AppSettings.defaults();
    // Start the initialization process
    _initFuture = _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    final serverUrl = _prefs.getString('localServerUrl') ?? defaultServerUrl;
    final apiKey = _prefs.getString('localServerApiKey') ?? localApiKey;
    final theme = _prefs.getString('preferredTheme') ?? defaultTheme;

    // Load TimeOfDay
    final timeString = _prefs.getString('defaultSessionStartTime');
    TimeOfDay? startTime;
    if (timeString != null) {
      final parts = timeString.split(':');
      if (parts.length == 2) {
        startTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    }

    _currentSettings = AppSettings(
      localServerUrl: serverUrl,
      localServerApiKey: apiKey,
      preferredTheme: theme,
      defaultSessionStartTime: startTime,
    );
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    await _prefs.setString('localServerUrl', _currentSettings.localServerUrl);
    await _prefs.setString(
        'localServerApiKey', _currentSettings.localServerApiKey);
    await _prefs.setString('preferredTheme', _currentSettings.preferredTheme);

    // Save TimeOfDay as "HH:mm"
    if (_currentSettings.defaultSessionStartTime != null) {
      final time = _currentSettings.defaultSessionStartTime!;
      await _prefs.setString(
          'defaultSessionStartTime', '${time.hour}:${time.minute}');
    } else {
      await _prefs.remove('defaultSessionStartTime');
    }
  }

  void updateSettings(AppSettings newSettings) {
    if (_currentSettings != newSettings) {
      _currentSettings = newSettings;
      _saveSettings();
      notifyListeners();
    }
  }
}