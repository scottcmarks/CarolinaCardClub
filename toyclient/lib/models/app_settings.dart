// lib/models/app_settings.dart

import 'package:equatable/equatable.dart';
import 'package:shared/shared.dart';

/// A data class to hold settings for the server URL and API key.
/// It now uses Equatable for value-based comparison.
class AppSettings extends Equatable {
  final String serverUrl;
  final String apiKey;

  const AppSettings({
    required this.serverUrl,
    required this.apiKey,
  });

  factory AppSettings.defaults() {
    return const AppSettings(
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

  // This is the magic from Equatable. It tells Dart to compare objects
  // based on the values of these properties.
  @override
  List<Object?> get props => [serverUrl, apiKey];
}
