// client/lib/models/app_settings.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// **FIX**: Import the sibling package
import 'package:shared/shared.dart';

class AppSettings {
  final String localServerUrl;
  final String localServerApiKey;
  final String preferredTheme;
  final TimeOfDay? sessionStartTime;

  // Default values
  static const String defaultLocalServerUrl = defaultServerUrl;
  static const String defaultLocalTheme = defaultTheme;
  static const String defaultLocalApiKey = localApiKey;


  // Keys for SharedPreferences
  static const String _keyServerUrl = 'server_url';
  static const String _keyApiKey = 'api_key';
  static const String _keyTheme = 'theme';
  static const String _keyStartHour = 'default_start_hour';
  static const String _keyStartMinute = 'default_start_minute';

  const AppSettings({
    required this.localServerUrl,
    required this.localServerApiKey,
    required this.preferredTheme,
    this.sessionStartTime,
  });

  factory AppSettings.defaults() {
    return const AppSettings(
      localServerUrl: defaultLocalServerUrl,
      localServerApiKey: defaultLocalApiKey,
      preferredTheme: defaultLocalTheme,
      sessionStartTime: null,
    );
  }

  AppSettings copyWith({
    String? localServerUrl,
    String? localServerApiKey,
    String? preferredTheme,
    TimeOfDay? sessionStartTime,
  }) {
    return AppSettings(
      localServerUrl: localServerUrl ?? this.localServerUrl,
      localServerApiKey: localServerApiKey ?? this.localServerApiKey,
      preferredTheme: preferredTheme ?? this.preferredTheme,
      sessionStartTime:
          sessionStartTime ?? this.sessionStartTime,
    );
  }

  // --- Persistence Helpers ---

  factory AppSettings.fromPrefs(SharedPreferences prefs) {
    TimeOfDay? loadedTime;
    if (prefs.containsKey(_keyStartHour) && prefs.containsKey(_keyStartMinute)) {
      loadedTime = TimeOfDay(
        hour: prefs.getInt(_keyStartHour)!,
        minute: prefs.getInt(_keyStartMinute)!,
      );
    }

    return AppSettings(
      localServerUrl:
          prefs.getString(_keyServerUrl) ?? defaultLocalServerUrl,
      localServerApiKey:
          prefs.getString(_keyApiKey) ?? defaultLocalApiKey,
      preferredTheme:
          prefs.getString(_keyTheme) ?? defaultTheme,
      sessionStartTime: loadedTime,
    );
  }

  Future<void> saveToPrefs(SharedPreferences prefs) async {
    await prefs.setString(_keyServerUrl, localServerUrl);
    await prefs.setString(_keyApiKey, localServerApiKey);
    await prefs.setString(_keyTheme, preferredTheme);

    if (sessionStartTime != null) {
      await prefs.setInt(_keyStartHour, sessionStartTime!.hour);
      await prefs.setInt(_keyStartMinute, sessionStartTime!.minute);
    } else {
      await prefs.remove(_keyStartHour);
      await prefs.remove(_keyStartMinute);
    }
  }
}