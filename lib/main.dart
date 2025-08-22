// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

// Providers
import 'providers/app_settings_provider.dart';
import 'providers/database_provider.dart';
import 'providers/time_provider.dart';


// Widgets
import 'widgets/carolina_card_club_app.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Required to ensure the window manager can be initialized
  await windowManager.ensureInitialized();

  // Define your initial window size and position
  WindowOptions windowOptions = WindowOptions(
    size: const Size(1200, 800), // Desired initial width and height
    center: true, // Center the window on the screen
    minimumSize: const Size(800, 600), // Optional: Set a minimum size
    // You can also set maximumSize, backgroundColor, etc.
  );

  // Set the window options
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  final appSettingsProvider = AppSettingsProvider();
  await appSettingsProvider.loadSettings();

  // Wrap the entire application with MultiProvider to register all top-level providers.
  // This makes these providers accessible from anywhere in your widget tree below this point.
  runApp(
    MultiProvider(
      providers: [
        // 1. App Settings Provider
        // Manages a collection of application settings like filter preferences, theme, etc.
        ChangeNotifierProvider(create: (_) => appSettingsProvider),

        // 2. Time Provider
        // Manages application-wide time settings or operations.
        ChangeNotifierProvider(create: (_) => TimeProvider()),

        // 3. Glue for cross-notification
        ChangeNotifierProxyProvider<AppSettingsProvider, DatabaseProvider>(
          // `create` is only called once when the provider is first created.
          //   Database Helper Provider
          //   Manages interactions with your local database, likely fetching and updating data.
          create: (_) => DatabaseProvider(),
          // `update` is called whenever AppSettingsProvider notifies listeners.
          update: (_, appSettings, previousDatabaseProvider) {
            final databaseProvider = previousDatabaseProvider ?? DatabaseProvider();
            databaseProvider.injectAppSettingsProvider(appSettings); // Inject the AppSettings
            return databaseProvider; // Return the (potentially updated) DatabaseProvider
          },
        ),

      ],
      child: const CarolinaCardClubApp(), // The root widget of your application
    ),
  );
}
