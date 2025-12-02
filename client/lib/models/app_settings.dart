// client/lib/models/app_settings.dart

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
  factory AppSettings.defaults() {
    return AppSettings(
      localServerUrl: defaultServerUrl,
      localServerApiKey: localApiKey,
      preferredTheme: defaultTheme,
      defaultSessionStartTime: const TimeOfDay(hour: defaultSessionHour, minute: defaultSessionMinute),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          runtimeType == other.runtimeType &&
          localServerUrl == other.localServerUrl &&
          localServerApiKey == other.localServerApiKey &&
          preferredTheme == other.preferredTheme &&
          defaultSessionStartTime == other.defaultSessionStartTime;

  @override
  int get hashCode =>
      localServerUrl.hashCode ^
      localServerApiKey.hashCode ^
      preferredTheme.hashCode ^
      defaultSessionStartTime.hashCode;
}