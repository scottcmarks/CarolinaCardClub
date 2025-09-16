// client/lib/widgets/carolina_card_club_app.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/api_provider.dart';
import '../providers/app_settings_provider.dart';
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
          // Use a FutureBuilder to wait for settings to load
          home: FutureBuilder(
            future: appSettings.initializationComplete,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                // Settings are loaded, now handle the connection
                return const ConnectionHandler();
              }
              // While settings are loading, show a spinner
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
  bool _isDialogShowing = false;

  @override
  void initState() {
    super.initState();
    Provider.of<ApiProvider>(context, listen: false).initialize();
  }

  void _showSettingsDialog(BuildContext context) {
    // This ensures we don't try to show a dialog when one is already visible
    if (_isDialogShowing) return;
    _isDialogShowing = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return const ServerSettingsDialog();
          },
        ).then((_) {
           // When the dialog is dismissed, reset the flag
          _isDialogShowing = false;
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
            return const MainSplitViewPage();
          case ConnectionStatus.connecting:
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          case ConnectionStatus.failed:
          case ConnectionStatus.disconnected:
            // The connection has failed, show the dialog.
            _showSettingsDialog(context);
            // And show a helpful message on the screen behind the dialog.
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