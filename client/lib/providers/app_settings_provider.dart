// client/lib/providers/app_settings_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

class AppSettingsProvider with ChangeNotifier {
  AppSettings _currentSettings = AppSettings.defaults();
  late Future<void> initializationComplete;

  AppSettingsProvider() {
    initializationComplete = _loadSettings();
  }

  AppSettings get currentSettings => _currentSettings;

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    // Assuming AppSettings has a fromJson/fromMap or we load fields manually.
    // We load into the existing model structure.
    _currentSettings = AppSettings.fromPrefs(prefs);
    notifyListeners();
  }

  /// Updates the settings and persists them to disk.
  /// Returns a Future so callers can wait for the save to complete.
  Future<void> updateSettings(AppSettings newSettings) async {
    _currentSettings = newSettings;
    notifyListeners(); // Update UI immediately

    final prefs = await SharedPreferences.getInstance();
    await _currentSettings.saveToPrefs(prefs);
  }

  // Optional: Reset logic if you have it
  Future<void> resetSettings() async {
    await updateSettings(AppSettings.defaults());
  }
}