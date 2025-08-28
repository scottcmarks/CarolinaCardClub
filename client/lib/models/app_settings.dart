// app_settings.dart
import 'package:flutter/material.dart';

class AppSettings {
  final bool showOnlyActiveSessions;
  final TimeOfDay? defaultSessionStartTime;
  final Duration? clockOffset;
  final String preferredTheme;     // Example: Theme preference (e.g., 'light', 'dark')
  final String remoteDatabaseUrl;

  // Constructor
  const AppSettings({
    this.showOnlyActiveSessions = false, // Provide default values
    this.clockOffset = const Duration(microseconds:0),
    this.defaultSessionStartTime = const TimeOfDay(hour:19, minute:30),
    this.preferredTheme = 'light',
    this.remoteDatabaseUrl = 'https://carolinacardclub.com/CarolinaCardClub.db',
  });

  // copyWith method for immutability
  // This is a crucial pattern for data classes in Flutter, especially with ChangeNotifier.
  AppSettings copyWith({
    bool? showOnlyActiveSessions,
    TimeOfDay? defaultSessionStartTime,
    Duration? clockOffset,
    String? preferredTheme,
    String? remoteDatabaseUrl,
  }) {
    return AppSettings(
      showOnlyActiveSessions: showOnlyActiveSessions ?? this.showOnlyActiveSessions,
      defaultSessionStartTime: defaultSessionStartTime ?? this.defaultSessionStartTime,
      clockOffset: clockOffset ?? this.clockOffset,
      preferredTheme: preferredTheme ?? this.preferredTheme,
      remoteDatabaseUrl: remoteDatabaseUrl ?? this.remoteDatabaseUrl,
    );
  }

  // Optional: Override toString for better debugging
  @override
  String toString() {
    return '''AppSettings(showOnlyActiveSessions: $showOnlyActiveSessions,
                          defaultSessionStartTime: $defaultSessionStartTime,
                          clockOffset: $clockOffset,
                          preferredTheme: $preferredTheme,
                          remoteDatabaseUrl: $remoteDatabaseUrl)''';
  }

  // Optional: Implement equality for easier comparison
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          runtimeType == other.runtimeType &&
          showOnlyActiveSessions == other.showOnlyActiveSessions &&
          defaultSessionStartTime == other.defaultSessionStartTime &&
          clockOffset == other.clockOffset &&
          preferredTheme == other.preferredTheme &&
          remoteDatabaseUrl == other.remoteDatabaseUrl;

  @override
  int get hashCode => showOnlyActiveSessions.hashCode
                    ^ defaultSessionStartTime.hashCode
                    ^ clockOffset.hashCode
                    ^ preferredTheme.hashCode
                    ^ remoteDatabaseUrl.hashCode;
}
