// client/lib/main.dart

import 'dart:developer'; // Import for the debugger() function
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/app_settings.dart';
import 'providers/app_settings_provider.dart';
import 'providers/api_provider.dart';
import 'providers/time_provider.dart';
import 'widgets/main_split_view_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pre-load settings so they are available from the start.
  final appSettingsProvider = AppSettingsProvider();
  await appSettingsProvider.loadSettings();

  final timeProvider = TimeProvider();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: timeProvider),
        ChangeNotifierProvider.value(value: appSettingsProvider),
        ChangeNotifierProxyProvider<AppSettingsProvider, ApiProvider>(
          // 'create' is called once to build the initial ApiProvider.
          create: (context) {
            final apiProvider = ApiProvider(appSettingsProvider);
            // Kick off the very first connection attempt.
            // debugger();
            apiProvider.initialize();
            // THE FIX: Schedule initialize() to run after a 1-second delay.
            // This detaches the start of the connection from the widget build cycle.
            // Future.delayed(const Duration(seconds: 1), () {
            //   print("--> [MAIN] Delay complete. Calling apiProvider.initialize().");
            //   apiProvider.initialize();
            // });
            return apiProvider;
          },
          // 'update' is called whenever AppSettingsProvider notifies listeners.
          update: (context, appSettings, previousApiProvider) {
            // This is the magic: it tells the ApiProvider about the new settings.
            previousApiProvider?.updateAppSettings(appSettings);
            return previousApiProvider!;
          },
        ),
      ],
      child: const CarolinaCardClubApp(),
    ),
  );
}

class CarolinaCardClubApp extends StatelessWidget {
  const CarolinaCardClubApp({super.key});

  @override
  Widget build(BuildContext context) {
    // This correctly watches the provider for changes to its connectionFuture.
    final apiProvider = context.watch<ApiProvider>();

    return FutureBuilder(
      future: apiProvider.connectionFuture,
      builder: (context, snapshot) {
        print(
            '--> [MAIN] FutureBuilder rebuilding. State: ${snapshot.connectionState}, HasError: ${snapshot.hasError}');

        if (snapshot.hasError) {
          print(
              '--> [MAIN] FutureBuilder: STATE has ERROR. Building error screen. Error: ${snapshot.error}');
          return MaterialApp(
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            themeMode: ThemeMode.system,
            home: InitializationErrorScreen(
              error: snapshot.error,
              onRetry: () {
                print(
                  '--> [MAIN] FutureBuilder: STATE has ERROR. Retrying...');
              },
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.done) {
          print(
              '--> [MAIN] FutureBuilder: STATE is DONE and has NO ERROR. Building main app.');
          return Consumer<AppSettingsProvider>(
            builder: (context, appSettings, child) {
              return MaterialApp(
                title: 'Carolina Card Club',
                theme: appSettings.currentSettings.preferredTheme == 'dark'
                    ? ThemeData.dark()
                    : ThemeData.light(),
                home: const MainSplitViewPage(),
              );
            },
          );
        }

        // Otherwise, show the loading screen.
        final serverUrl =
            context.read<AppSettingsProvider>().currentSettings.localServerUrl;
        print(
            '--> [MAIN] FutureBuilder: STATE is WAITING. Building loading screen.');
        return MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    'Connecting to server at...\n$serverUrl',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A dedicated screen to show when the app fails to initialize.
class InitializationErrorScreen extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const InitializationErrorScreen({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    // Get the current settings to display the failed URL.
    final settingsProvider = context.watch<AppSettingsProvider>();
    final failedUrl = settingsProvider.currentSettings.localServerUrl;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 24),
              const Text(
                'Connection Failed',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Could not connect to the server at:\n$failedUrl',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.settings),
                label: const Text('Start the Server or Change Settings & Retry'),
                onPressed: () async {
                  await showDialog<bool>(
                    context: context,
                    builder: (context) => const ServerUrlUpdateDialog(),
                  );
                  // No need to call onRetry, as the provider handles the reconnect.
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A dialog that allows the user to update the server URL.
class ServerUrlUpdateDialog extends StatefulWidget {
  const ServerUrlUpdateDialog({super.key});

  @override
  State<ServerUrlUpdateDialog> createState() => _ServerUrlUpdateDialogState();
}

class _ServerUrlUpdateDialogState extends State<ServerUrlUpdateDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    // Pre-fill the text field with the current server URL.
    final initialUrl =
        context.read<AppSettingsProvider>().currentSettings.localServerUrl;
    _controller = TextEditingController(text: initialUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _saveAndClose() {
    final settingsProvider = context.read<AppSettingsProvider>();
    final newUrl = _controller.text;

    // Create a new settings object with the updated URL.
    final newSettings = settingsProvider.currentSettings.copyWith(
      localServerUrl: newUrl,
    );

    // Update the provider. This also saves it to storage and triggers the
    // ApiProvider to reconnect via the ChangeNotifierProxyProvider.
    settingsProvider.updateSettings(newSettings);

    // Pop the dialog.
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Server Settings'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'Server URL',
          hintText: 'http://127.0.0.1:8080',
        ),
        keyboardType: TextInputType.url,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saveAndClose,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
