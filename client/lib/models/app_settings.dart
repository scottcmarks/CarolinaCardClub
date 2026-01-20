// client/lib/models/app_settings.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// **FIX**: Import the sibling package
import 'package:shared/shared.dart';

class AppSettings {
  final String localServerUrl;
  final String localServerApiKey;
  final String preferredTheme;
  final TimeOfDay? defaultSessionStartTime;

  // Default values
  static const String defaultLocalServerUrl = 'http://172.20.10.2:5109';

  // **FIX**: Now uses the constant from the shared package
  static const String defaultApiKey = localApiKey;

  static const String defaultTheme = 'system';

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
    this.defaultSessionStartTime,
  });

  factory AppSettings.defaults() {
    return const AppSettings(
      localServerUrl: defaultLocalServerUrl,
      localServerApiKey: defaultApiKey,
      preferredTheme: defaultTheme,
      defaultSessionStartTime: null,
    );
  }

  AppSettings copyWith({
    String? localServerUrl,
    String? localServerApiKey,
    String? preferredTheme,
    TimeOfDay? defaultSessionStartTime,
  }) {
    return AppSettings(
      localServerUrl: localServerUrl ?? this.localServerUrl,
      localServerApiKey: localServerApiKey ?? this.localServerApiKey,
      preferredTheme: preferredTheme ?? this.preferredTheme,
      defaultSessionStartTime:
          defaultSessionStartTime ?? this.defaultSessionStartTime,
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
          prefs.getString(_keyApiKey) ?? defaultApiKey,
      preferredTheme:
          prefs.getString(_keyTheme) ?? defaultTheme,
      defaultSessionStartTime: loadedTime,
    );
  }

  Future<void> saveToPrefs(SharedPreferences prefs) async {
    await prefs.setString(_keyServerUrl, localServerUrl);
    await prefs.setString(_keyApiKey, localServerApiKey);
    await prefs.setString(_keyTheme, preferredTheme);

    if (defaultSessionStartTime != null) {
      await prefs.setInt(_keyStartHour, defaultSessionStartTime!.hour);
      await prefs.setInt(_keyStartMinute, defaultSessionStartTime!.minute);
    } else {
      await prefs.remove(_keyStartHour);
      await prefs.remove(_keyStartMinute);
    }
  }
}