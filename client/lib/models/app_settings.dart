// client/lib/models/app_settings.dart

import 'package:flutter/material.dart';

class AppSettings {
  // REMOVED: remoteDatabaseUrl
  // ADDED: localServerUrl
  final String localServerUrl;
  final String localServerApiKey; // Added for client-server auth
  final bool showOnlyActiveSessions;
  final TimeOfDay? defaultSessionStartTime;

  AppSettings({
    required this.localServerUrl,
    required this.localServerApiKey,
    this.showOnlyActiveSessions = false,
    this.defaultSessionStartTime,
  });

  // Method to create a copy with modified fields
  AppSettings copyWith({
    String? localServerUrl,
    String? localServerApiKey,
    bool? showOnlyActiveSessions,
    TimeOfDay? defaultSessionStartTime,
  }) {
    return AppSettings(
      localServerUrl: localServerUrl ?? this.localServerUrl,
      localServerApiKey: localServerApiKey ?? this.localServerApiKey,
      showOnlyActiveSessions: showOnlyActiveSessions ?? this.showOnlyActiveSessions,
      defaultSessionStartTime: defaultSessionStartTime ?? this.defaultSessionStartTime,
    );
  }
}
