// client/lib/providers/app_settings_provider.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import 'package:shared/shared.dart';

class AppSettingsProvider with ChangeNotifier {
  late SharedPreferences _prefs;
  late AppSettings _currentSettings;

  // Use a Future to signal when initialization is complete
  late Future<void> _initFuture;

  AppSettings get currentSettings => _currentSettings;
  Future<void> get initializationComplete => _initFuture;

  AppSettingsProvider() {
    _currentSettings = AppSettings(
      localServerUrl: defaultServerUrl,
      localServerApiKey: localApiKey,
      preferredTheme: defaultTheme,
    );
    // Start the initialization process
    _initFuture = _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    final serverUrl = _prefs.getString('localServerUrl') ?? defaultServerUrl;
    final apiKey = _prefs.getString('localServerApiKey') ?? localApiKey;
    final theme = _prefs.getString('preferredTheme') ?? defaultTheme;

    _currentSettings = AppSettings(
      localServerUrl: serverUrl,
      localServerApiKey: apiKey,
      preferredTheme: theme,
    );
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    await _prefs.setString('localServerUrl', _currentSettings.localServerUrl);
    await _prefs.setString('localServerApiKey', _currentSettings.localServerApiKey);
    await _prefs.setString('preferredTheme', _currentSettings.preferredTheme);
  }

  void updateSettings(AppSettings newSettings) {
    if (_currentSettings != newSettings) {
      _currentSettings = newSettings;
      _saveSettings();
      notifyListeners();
    }
  }
}