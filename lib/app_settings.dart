// app_settings.dart
import 'package:flutter/material.dart';

class AppSettings {
  final bool showOnlyActiveSessions;
  final TimeOfDay? defaultStartTime; // Example: Add a default start time setting
  final String preferredTheme;     // Example: Theme preference (e.g., 'light', 'dark')

  // Constructor
  const AppSettings({
    this.showOnlyActiveSessions = false, // Provide default values
    this.defaultStartTime,
    this.preferredTheme = 'light',
  });

  // copyWith method for immutability
  // This is a crucial pattern for data classes in Flutter, especially with ChangeNotifier.
  AppSettings copyWith({
    bool? showOnlyActiveSessions,
    TimeOfDay? defaultStartTime,
    String? preferredTheme,
  }) {
    return AppSettings(
      showOnlyActiveSessions: showOnlyActiveSessions ?? this.showOnlyActiveSessions,
      defaultStartTime: defaultStartTime ?? this.defaultStartTime,
      preferredTheme: preferredTheme ?? this.preferredTheme,
    );
  }

  // Optional: Override toString for better debugging
  @override
  String toString() {
    return 'AppSettings(showOnlyActiveSessions: $showOnlyActiveSessions, defaultStartTime: $defaultStartTime, preferredTheme: $preferredTheme)';
  }

  // Optional: Implement equality for easier comparison
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          runtimeType == other.runtimeType &&
          showOnlyActiveSessions == other.showOnlyActiveSessions &&
          defaultStartTime == other.defaultStartTime &&
          preferredTheme == other.preferredTheme;

  @override
  int get hashCode => showOnlyActiveSessions.hashCode ^ defaultStartTime.hashCode ^ preferredTheme.hashCode;
}
