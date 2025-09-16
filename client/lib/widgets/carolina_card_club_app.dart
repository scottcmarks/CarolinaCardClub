// client/lib/widgets/carolina_card_club_app.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/api_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/session_filter_provider.dart';
import '../providers/time_provider.dart';
import 'main_split_view_page.dart';
import 'settings_page.dart';

class CarolinaCardClubApp extends StatelessWidget {
  const CarolinaCardClubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
        ChangeNotifierProxyProvider<AppSettingsProvider, ApiProvider>(
          create: (context) => ApiProvider(
              Provider.of<AppSettingsProvider>(context, listen: false)),
          update: (_, appSettings, apiProvider) {
            apiProvider?.updateAppSettings(appSettings);
            return apiProvider!;
          },
        ),
        ChangeNotifierProvider(create: (_) => TimeProvider()),
        ChangeNotifierProvider(create: (_) => SessionFilterProvider()),
      ],
      child: Consumer<AppSettingsProvider>(
        builder: (context, appSettings, _) {
          return MaterialApp(
            title: 'Carolina Card Club',
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            themeMode: appSettings.currentSettings.preferredTheme == 'dark'
                ? ThemeMode.dark
                : ThemeMode.light,
            home: FutureBuilder(
              future: appSettings.initializationComplete,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return const ConnectionHandler();
                }
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class ConnectionHandler extends StatefulWidget {
  const ConnectionHandler({super.key});

  @override
  State<ConnectionHandler> createState() => _ConnectionHandlerState();
}

class _ConnectionHandlerState extends State<ConnectionHandler> {
  bool _dialogIsShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<ApiProvider>(context, listen: false).initialize();
      }
    });
  }

  void _showSettingsDialogIfNeeded(BuildContext context) {
    // This logic prevents the dialog from showing multiple times.
    if (_dialogIsShowing) return;
    _dialogIsShowing = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return const ServerSettingsDialog();
          },
        ).then((_) {
          // Reset the flag when the dialog is dismissed.
          _dialogIsShowing = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ApiProvider>(
      builder: (context, api, _) {
        switch (api.connectionStatus) {
          case ConnectionStatus.connected:
            // If we connect successfully, make sure the dialog isn't showing.
            if (_dialogIsShowing) {
              Navigator.of(context).pop();
            }
            return const MainSplitViewPage();
          case ConnectionStatus.connecting:
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          case ConnectionStatus.failed:
          case ConnectionStatus.disconnected:
            _showSettingsDialogIfNeeded(context);
            return Scaffold(
              appBar: AppBar(title: const Text('Connection Failed')),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    api.lastError ?? 'Could not connect to the server.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                  ),
                ),
              ),
            );
        }
      },
    );
  }
}