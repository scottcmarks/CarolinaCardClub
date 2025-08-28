// client/lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/api_provider.dart';
import 'providers/time_provider.dart';
import 'providers/app_settings_provider.dart';
import 'widgets/main_split_view_page.dart';

void main() {
  runApp(const CarolinaCardClubApp());
}

class CarolinaCardClubApp extends StatelessWidget {
  const CarolinaCardClubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // These two providers are independent
        ChangeNotifierProvider(create: (context) => TimeProvider()),
        ChangeNotifierProvider(create: (context) => AppSettingsProvider()),

        // This is the corrected provider setup.
        // ChangeNotifierProxyProvider creates an ApiProvider and automatically
        // gives it the AppSettingsProvider it depends on.
        ChangeNotifierProxyProvider<AppSettingsProvider, ApiProvider>(
          // This function creates the ApiProvider
          create: (context) => ApiProvider(
            // It's created with a reference to the AppSettingsProvider
            Provider.of<AppSettingsProvider>(context, listen: false),
          ),
          // This function is called whenever AppSettingsProvider updates.
          // We don't need it here, but it's required by the provider.
          update: (context, appSettings, previousApiProvider) =>
              previousApiProvider ?? ApiProvider(appSettings),
        ),
      ],
      child: MaterialApp(
        title: 'Carolina Card Club',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const MainSplitViewPage(),
      ),
    );
  }
}
