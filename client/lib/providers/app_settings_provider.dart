// client/lib/providers/app_settings_provider.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

class AppSettingsProvider with ChangeNotifier {
  // This line caused the error "Required named parameter serverIp...".
  // With the defaults added to AppSettings() above, this is now valid.
  AppSettings _currentSettings = AppSettings();

  static const String _storageKey = 'ccc_app_settings';

  AppSettings get currentSettings => _currentSettings;

  AppSettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encoded = prefs.getString(_storageKey);
    if (encoded != null) {
      try {
        _currentSettings = AppSettings.fromMap(json.decode(encoded));
        notifyListeners();
      } catch (e) {
        debugPrint("Error decoding settings: $e");
      }
    }
  }

  Future<void> updateSettings(AppSettings newSettings) async {
    _currentSettings = newSettings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, json.encode(newSettings.toMap()));
    notifyListeners();
  }
}