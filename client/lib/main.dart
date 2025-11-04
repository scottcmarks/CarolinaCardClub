// client/lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/api_provider.dart';
import 'providers/app_settings_provider.dart';
import 'providers/session_filter_provider.dart';
import 'providers/time_provider.dart';
import 'widgets/carolina_card_club_app.dart';

void main() {
  // WidgetsFlutterBinding.ensureInitialized() is needed for async operations before runApp
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        // AppSettingsProvider now needs to be created differently to handle async loading
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
        ChangeNotifierProxyProvider<AppSettingsProvider, ApiProvider>(
          create: (context) => ApiProvider(
              Provider.of<AppSettingsProvider>(context, listen: false)),
          // **MODIFICATION**: Removed ..initialize() from create
          update: (_, appSettings, apiProvider) {
            apiProvider?.updateAppSettings(appSettings);
            return apiProvider!;
          },
        ),
        ChangeNotifierProvider(create: (_) => TimeProvider()),
        ChangeNotifierProvider(create: (_) => SessionFilterProvider()),
      ],
      child: const CarolinaCardClubApp(),
    ),
  );
}