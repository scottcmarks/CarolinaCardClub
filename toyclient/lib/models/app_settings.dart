// lib/models/app_settings.dart

import 'package:shared/shared.dart';

/// A data class to hold settings for the server URL and API key.
class AppSettings {
  final String serverUrl;
  final String apiKey;

  // Constructor now requires both parameters.
  AppSettings({
    required this.serverUrl,
    required this.apiKey,
  });

  // A factory constructor to create default settings.
  factory AppSettings.defaults() {
    return AppSettings(
      serverUrl: '', // Starts with no server URL.
      apiKey: localApiKey, // Initializes with the key from the real shared module.
    );
  }
}
