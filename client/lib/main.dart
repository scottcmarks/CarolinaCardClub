// client/lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:db_connection/db_connection.dart';
import 'package:shared/shared.dart';

import 'core/app_config.dart';
import 'models/app_settings.dart';
import 'providers/api_provider.dart';
import 'providers/app_settings_provider.dart';
import 'providers/time_provider.dart';
import 'pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = await AppConfig.load();
  final initialSettings = await AppSettingsProvider.loadInitialSettings(config);
  runApp(CarolinaCardClubApp(config: config, initialSettings: initialSettings));
}

class CarolinaCardClubApp extends StatelessWidget {
  final AppConfig config;
  final AppSettings initialSettings;

  const CarolinaCardClubApp({super.key, required this.config, required this.initialSettings});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppSettingsProvider(config, initialSettings)),
        ChangeNotifierProvider(create: (_) => TimeProvider()),
        ChangeNotifierProvider(create: (_) => DbConnectionProvider()),

        // When settings change, notify the connection provider of the new server URL.
        ChangeNotifierProxyProvider<AppSettingsProvider, DbConnectionProvider>(
          create: (context) => Provider.of<DbConnectionProvider>(context, listen: false),
          update: (context, settingsProv, connectionProv) {
            final serverUrl = 'http://${settingsProv.currentSettings.serverIp}:${settingsProv.currentSettings.serverPort}';
            connectionProv!.setServerUrl(serverUrl);
            return connectionProv;
          },
        ),

        ChangeNotifierProxyProvider3<AppSettingsProvider, TimeProvider, DbConnectionProvider, ApiProvider>(
          create: (context) {
            final settingsProv = Provider.of<AppSettingsProvider>(context, listen: false);
            final timeProv = Provider.of<TimeProvider>(context, listen: false);
            final connProv = Provider.of<DbConnectionProvider>(context, listen: false);
            return ApiProvider(settingsProv.currentSettings, connProv, timeProv);
          },
          update: (context, settingsProv, timeProv, connProv, previous) {
            if (previous != null) {
              previous.applySettings(settingsProv.currentSettings);
              return previous;
            }
            return ApiProvider(settingsProv.currentSettings, connProv, timeProv);
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
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(Shared.carolinaBlue),
                foregroundColor: Colors.white,
              ),
            ),
            home: const HomePage(),
          );
        },
      ),
    );
  }
}
