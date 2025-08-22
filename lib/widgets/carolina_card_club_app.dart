// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

// Providers
import '../providers/app_settings_provider.dart';
import '../providers/database_provider.dart';
import '../providers/time_provider.dart';


// Widgets
import 'main_split_view_page.dart';



class CarolinaCardClubApp extends StatelessWidget {
  const CarolinaCardClubApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MaterialApp sets up the basic Material Design theme and navigation for your app.
    return MaterialApp(
      title: 'CCCP', // This is the title for the OS, often seen in task switchers
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
