// app_settings.dart
import 'package:flutter/material.dart';

class AppSettings {
  final bool showOnlyActiveSessions;
  final TimeOfDay? defaultStartTime; // Example: Add a default start time setting
  final String preferredTheme;     // Example: Theme preference (e.g., 'light', 'dark')
  final String remoteDatabaseUrl;

  // Constructor
  const AppSettings({
    this.showOnlyActiveSessions = false, // Provide default values
    this.defaultStartTime = const TimeOfDay(hour:19, minute:30),
    this.preferredTheme = 'light',
    this.remoteDatabaseUrl = 'https://carolinacardclub.com/CarolinaCardClub.db',
  });

  // copyWith method for immutability
  // This is a crucial pattern for data classes in Flutter, especially with ChangeNotifier.
  AppSettings copyWith({
    bool? showOnlyActiveSessions,
    TimeOfDay? defaultStartTime,
    String? preferredTheme,
    String? remoteDatabaseUrl,
  }) {
    return AppSettings(
      showOnlyActiveSessions: showOnlyActiveSessions ?? this.showOnlyActiveSessions,
      defaultStartTime: defaultStartTime ?? this.defaultStartTime,
      preferredTheme: preferredTheme ?? this.preferredTheme,
      remoteDatabaseUrl: remoteDatabaseUrl ?? this.remoteDatabaseUrl,
    );
  }

  // Optional: Override toString for better debugging
  @override
  String toString() {
    return '''AppSettings(showOnlyActiveSessions: $showOnlyActiveSessions,
                          defaultStartTime: $defaultStartTime,
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
          defaultStartTime == other.defaultStartTime &&
          preferredTheme == other.preferredTheme &&
          remoteDatabaseUrl == other.remoteDatabaseUrl;

  @override
  int get hashCode => showOnlyActiveSessions.hashCode
                    ^ defaultStartTime.hashCode
                    ^ preferredTheme.hashCode
                    ^ remoteDatabaseUrl.hashCode;
}
