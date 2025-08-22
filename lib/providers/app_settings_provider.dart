// app_settings_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

class AppSettingsProvider extends ChangeNotifier {
  AppSettings _currentSettings = const AppSettings();

  AppSettings get currentSettings => _currentSettings;

  // Key constants for SharedPreferences
  static const String _keyShowOnlyActiveSessions = 'showOnlyActiveSessions';
  static const String _keyDefaultStartTime = 'defaultStartTime';
  static const String _keyPreferredTheme = 'preferredTheme';
  static const String _keyRemoteDatabaseUrl = 'remoteDatabaseUrl';

  // Add a loadSettings method to load settings on app startup
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final bool? showOnlyActiveSessions = prefs.getBool(_keyShowOnlyActiveSessions);
    final String? defaultStartTimeString = prefs.getString(_keyDefaultStartTime);
    final String? preferredTheme = prefs.getString(_keyPreferredTheme);
    final String? remoteDatabaseUrl = prefs.getString(_keyRemoteDatabaseUrl);

    _currentSettings = _currentSettings.copyWith(
      showOnlyActiveSessions: showOnlyActiveSessions,
      defaultStartTime: _timeOfDayFromString(defaultStartTimeString),
      preferredTheme: preferredTheme,
      remoteDatabaseUrl: remoteDatabaseUrl,
    );
    notifyListeners(); // Notify listeners that settings have been loaded
  }

  // Helper to convert TimeOfDay to String for storage
  String? _timeOfDayToString(TimeOfDay? time) {
    if (time == null) return null;
    return '${time.hour}:${time.minute}';
  }

  // Helper to convert String back to TimeOfDay
  TimeOfDay? _timeOfDayFromString(String? timeString) {
    if (timeString == null || timeString.isEmpty) return null;
    final parts = timeString.split(':');
    if (parts.length == 2) {
      return TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 0, // Handle parsing errors
        minute: int.tryParse(parts[1]) ?? 0,
      );
    }
    return null;
  }

  // Combines logic for updating settings and persisting them
  void updateSettings({
    bool? showOnlyActiveSessions,
    TimeOfDay? defaultStartTime,
    String? preferredTheme,
    String? remoteDatabaseUrl,
  }) async { // Make it async since it interacts with SharedPreferences
    final prefs = await SharedPreferences.getInstance();

    _currentSettings = _currentSettings.copyWith(
      showOnlyActiveSessions: showOnlyActiveSessions,
      defaultStartTime: defaultStartTime,
      preferredTheme: preferredTheme,
      remoteDatabaseUrl: remoteDatabaseUrl,
    );

    // Persist each setting if it was provided
    if (showOnlyActiveSessions != null) {
      await prefs.setBool(_keyShowOnlyActiveSessions, _currentSettings.showOnlyActiveSessions);
    }
    if (defaultStartTime != null) {
      await prefs.setString(_keyDefaultStartTime, _timeOfDayToString(_currentSettings.defaultStartTime)!);
    }
    if (preferredTheme != null) {
      await prefs.setString(_keyPreferredTheme, _currentSettings.preferredTheme);
    }
    if (remoteDatabaseUrl != null) {
      await prefs.setString(_keyRemoteDatabaseUrl, _currentSettings.remoteDatabaseUrl);
    }

    notifyListeners(); // Notify all listening widgets
  }

  // Individual update methods for clarity, now persisting changes
  void setShowOnlyActiveSessions(bool newValue) async {
    if (_currentSettings.showOnlyActiveSessions != newValue) {
      _currentSettings = _currentSettings.copyWith(showOnlyActiveSessions: newValue);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyShowOnlyActiveSessions, newValue); // Persist
      notifyListeners();
    }
  }

  void setDefaultStartTime(TimeOfDay newTime) async {
    if (_currentSettings.defaultStartTime != newTime) {
      _currentSettings = _currentSettings.copyWith(defaultStartTime: newTime);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyDefaultStartTime, _timeOfDayToString(newTime)!); // Persist
      notifyListeners();
    }
  }

  void setPreferredTheme(String newTheme) async {
    if (_currentSettings.preferredTheme != newTheme) {
      _currentSettings = _currentSettings.copyWith(preferredTheme: newTheme);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyPreferredTheme, newTheme); // Persist
      notifyListeners();
    }
  }

  void setRemoteDatabaseUrl(String newUrl) async {
    if (_currentSettings.remoteDatabaseUrl != newUrl) {
      _currentSettings = _currentSettings.copyWith(remoteDatabaseUrl: newUrl);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyRemoteDatabaseUrl, newUrl); // Persist
      notifyListeners();
    }
  }
}
