// lib/models/app_settings.dart

import 'package:shared/shared.dart';

/// A data class to hold settings for the server URL and API key.
class AppSettings {
  final String serverUrl;
  final String apiKey;

  AppSettings({
    required this.serverUrl,
    required this.apiKey,
  });

  factory AppSettings.defaults() {
    return AppSettings(
      serverUrl: '', // Starts with no server URL.
      apiKey: localApiKey, // Initializes with the key from the real shared module.
    );
  }

  /// Creates a copy of this AppSettings but with the given fields replaced with the new values.
  AppSettings copyWith({
    String? serverUrl,
    String? apiKey,
  }) {
    return AppSettings(
      serverUrl: serverUrl ?? this.serverUrl,
      apiKey: apiKey ?? this.apiKey,
    );
  }
}
