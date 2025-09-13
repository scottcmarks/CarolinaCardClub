import 'package:flutter/material.dart';

import 'package:shared/shared.dart';

/// A data class to hold all user-configurable application settings.
///
/// This class is immutable. To change a setting, create a new instance
/// using the [copyWith] method.
class AppSettings {
  final String localServerUrl;
  final String localServerApiKey;
  final String preferredTheme;
  final TimeOfDay? defaultSessionStartTime;

  AppSettings({
    required this.localServerUrl,
    required this.localServerApiKey,
    required this.preferredTheme,
    this.defaultSessionStartTime,
  });

  /// Creates a new [AppSettings] instance with updated values.
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

  /// A factory constructor to create default settings.
  ///
  /// This is used to initialize the [AppSettingsProvider] before the
  /// actual settings have been loaded from persistent storage, preventing
  /// initialization errors.
  factory AppSettings.defaults() {
    return AppSettings(
      localServerUrl: defaultServerUrl,
      localServerApiKey: localApiKey,
      preferredTheme: defaultTheme,
      defaultSessionStartTime: const TimeOfDay(hour: defaultSessionHour, minute: defaultSessionMinute),
    );
  }
}
