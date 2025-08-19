// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// --- Import your custom files ---
// Providers
import 'app_settings_provider.dart';
import 'database/database_provider.dart';
import 'time_provider.dart';
import 'app_settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

// Widgets
import 'main_split_view_page.dart';

// You might also have a common file for your settings "struct"
// import 'app_settings.dart'; // No direct import here, but AppSettingsProvider uses it


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

  // Wrap the entire application with MultiProvider to register all top-level providers.
  // This makes these providers accessible from anywhere in your widget tree below this point.
  runApp(
    MultiProvider(
      providers: [
        // 1. App Settings Provider
        // Manages a collection of application settings like filter preferences, theme, etc.
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()),

        // 2. Database Helper Provider
        // Manages interactions with your local database, likely fetching and updating data.
        ChangeNotifierProvider(create: (_) => DatabaseProvider()),

        // 3. Time Provider
        // Manages application-wide time settings or operations.
        ChangeNotifierProvider(create: (_) => TimeProvider()),

        // Add any other top-level ChangeNotifierProviders or other Providers here.
        // For example:
        // ChangeNotifierProvider(create: (_) => AuthProvider()),
        // Provider(create: (_) => AnalyticsService()),
      ],
      child: const MyApp(), // The root widget of your application
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MaterialApp sets up the basic Material Design theme and navigation for your app.
    return MaterialApp(
      title: 'Your Awesome Split View App', // This is the title for the OS, often seen in task switchers
      theme: ThemeData(
        primarySwatch: Colors.blue, // A basic primary color theme
        visualDensity: VisualDensity.adaptivePlatformDensity, // Adjusts density based on platform
        brightness: Provider.of<AppSettingsProvider>(context).currentSettings.preferredTheme == 'dark'
            ? Brightness.dark
            : Brightness.light,
      ),
      // The `home` widget is the first screen displayed when your app starts.
      home: const MainSplitViewPage(),
    );
  }
}
