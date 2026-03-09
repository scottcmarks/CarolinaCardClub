// client/lib/core/app_config.dart
//
// Deployment-specific runtime configuration loaded from assets/config.json.
// These are defaults that vary per device/deployment (API key, server address,
// table number). They are NOT user-editable; user preferences live in
// AppSettings (persisted via shared_preferences).

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared/shared.dart';

class AppConfig {
  final String localApiKey;
  final String serverIp;
  final int serverPort;
  final int? tableNumber;

  const AppConfig({
    required this.localApiKey,
    required this.serverIp,
    required this.serverPort,
    this.tableNumber,
  });

  static AppConfig get defaults => const AppConfig(
        localApiKey: Shared.defaultLocalApiKey,
        serverIp: Shared.defaultServerIp,
        serverPort: Shared.defaultServerPort,
      );

  static Future<AppConfig> load() async {
    try {
      final raw = await rootBundle.loadString('assets/config.json');
      final map = json.decode(raw) as Map<String, dynamic>;
      return AppConfig(
        localApiKey: map['localApiKey'] as String? ?? Shared.defaultLocalApiKey,
        serverIp: map['serverIp'] as String? ?? Shared.defaultServerIp,
        serverPort: map['serverPort'] as int? ?? Shared.defaultServerPort,
        tableNumber: map['tableNumber'] as int?,
      );
    } catch (_) {
      return defaults;
    }
  }
}
