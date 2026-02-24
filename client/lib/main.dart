// client/lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/api_provider.dart';
import 'providers/app_settings_provider.dart';
import 'providers/time_provider.dart';
import 'pages/home_page.dart';

void main() {
  runApp(const CarolinaCardClubApp());
}

class CarolinaCardClubApp extends StatelessWidget {
  const CarolinaCardClubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
        ChangeNotifierProvider(create: (_) => TimeProvider()),

        ChangeNotifierProxyProvider2<AppSettingsProvider, TimeProvider, ApiProvider>(
          create: (context) {
            final settingsProv = Provider.of<AppSettingsProvider>(context, listen: false);
            return ApiProvider(settingsProv.currentSettings);
          },
          update: (context, settingsProv, timeProv, previous) {
            // Ensure the API provider always has the latest settings and time offset
            final api = previous ?? ApiProvider(settingsProv.currentSettings);
            api.updateTimeOffset(timeProv.offset);
            return api;
          },
        ),
      ],
      child: Consumer<AppSettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'Carolina Card Club',
            debugShowCheckedModeBanner: false,
            themeMode: settings.currentSettings.preferredTheme == 'dark'
                ? ThemeMode.dark
                : ThemeMode.light,
            theme: ThemeData(
              primarySwatch: Colors.blue,
              useMaterial3: true,
              scaffoldBackgroundColor: Colors.white,
            ),
            home: const HomePage(),
          );
        },
      ),
    );
  }
}