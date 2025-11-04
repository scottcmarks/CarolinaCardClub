// client/lib/widgets/carolina_card_club_app.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/api_provider.dart';
import '../providers/app_settings_provider.dart';
import 'connection_failed_widget.dart';
import 'main_split_view_page.dart';
import 'settings_page.dart';

class CarolinaCardClubApp extends StatelessWidget {
  const CarolinaCardClubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppSettingsProvider>(
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
    );
  }
}

class ConnectionHandler extends StatefulWidget {
  const ConnectionHandler({super.key});

  @override
  State<ConnectionHandler> createState() => _ConnectionHandlerState();
}

class _ConnectionHandlerState extends State<ConnectionHandler> {
  // **NEW**: Add initState to trigger the connection
  @override
  void initState() {
    super.initState();
    // We are only in this widget BECAUSE AppSettingsProvider is ready.
    // This is now the correct time to start the first connection attempt.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ApiProvider>(context, listen: false).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ApiProvider>(
      builder: (context, api, _) {
        switch (api.connectionStatus) {
          case ConnectionStatus.connected:
            return const MainSplitViewPage();

          case ConnectionStatus.connecting:
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );

          case ConnectionStatus.failed:
          case ConnectionStatus.disconnected:
            // This will now only show if the *first* attempt (with
            // correct settings) actually fails.
            return Scaffold(
              body: ConnectionFailedWidget(
                errorMessage:
                    api.lastError ?? 'Could not connect to the server.',
                onRetry: api.retryConnection,
                onSettings: () => showServerSettingsDialog(context),
              ),
            );
        }
      },
    );
  }
}