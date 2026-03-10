// client/lib/main_tablet.dart
//
// Entry point for the tablet app (one per poker table).
// Build with: flutter build apk -t lib/main_tablet.dart
//
// The table assignment is stored in shared_preferences and set on first launch
// via TabletShell's setup screen. assets/config.json carries the server
// address and API key (shared across all devices).

import 'package:flutter/material.dart';
import 'core/app_config.dart';
import 'providers/app_settings_provider.dart';
import 'main.dart' show CarolinaCardClubApp;
import 'shells/tablet_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = await AppConfig.load();
  final initialSettings = await AppSettingsProvider.loadInitialSettings(config);
  runApp(CarolinaCardClubApp(
    config: config,
    initialSettings: initialSettings,
    home: const TabletShell(),
  ));
}
