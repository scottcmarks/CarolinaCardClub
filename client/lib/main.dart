import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/app_settings.dart';
import 'providers/app_settings_provider.dart';
import 'providers/api_provider.dart';
import 'providers/time_provider.dart';
import 'widgets/main_split_view_page.dart';

void main() async {
  // Use a completer to wait for the first frame to be rendered.
  final Completer<void> firstFrameCompleter = Completer<void>();
  WidgetsFlutterBinding.ensureInitialized();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    firstFrameCompleter.complete();
  });

  // Pre-load all providers before running the app.
  final appSettingsProvider = AppSettingsProvider();
  await appSettingsProvider.loadSettings();

  final apiProvider = ApiProvider(appSettingsProvider);
  final timeProvider = TimeProvider();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: timeProvider),
        ChangeNotifierProvider.value(value: appSettingsProvider),
        ChangeNotifierProvider.value(value: apiProvider),
        // Proxy provider is still useful for reacting to future settings changes.
        ChangeNotifierProxyProvider<AppSettingsProvider, ApiProvider>(
          create: (context) => apiProvider,
          update: (context, appSettings, previousApiProvider) {
            previousApiProvider?.updateAppSettings(appSettings);
            return previousApiProvider!;
          },
        ),
      ],
      child: const CarolinaCardClubApp(),
    ),
  );
  await firstFrameCompleter.future;
}

class CarolinaCardClubApp extends StatefulWidget {
  const CarolinaCardClubApp({super.key});

  @override
  State<CarolinaCardClubApp> createState() => _CarolinaCardClubAppState();
}

class _CarolinaCardClubAppState extends State<CarolinaCardClubApp> {
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Settings are already loaded, we just initialize the API connection.
    await context.read<ApiProvider>().initialize();
  }

  void _retryInitialization() {
    setState(() {
      _initFuture = _initializeApp();
    });
  }

  @override
  Widget build(BuildContext context) {
    final serverUrl =
        context.read<AppSettingsProvider>().currentSettings.localServerUrl;

    return FutureBuilder(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
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
        }

        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            themeMode: ThemeMode.system,
            home: InitializationErrorScreen(
              error: snapshot.error,
              onRetry: _retryInitialization,
            ),
          );
        }

        return Consumer<AppSettingsProvider>(
          builder: (context, appSettings, child) {
            return MaterialApp(
              title: 'Carolina Card Club',
              debugShowCheckedModeBanner: false,
              theme: appSettings.currentSettings.preferredTheme == 'dark'
                  ? ThemeData.dark()
                  : ThemeData.light(),
              home: const MainSplitViewPage(),
            );
          },
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
                // THE REQUESTED CHANGE: Updated button text.
                label: const Text('Start the Server or Change Settings & Retry'),
                onPressed: () async {
                  final bool? shouldRetry = await showDialog<bool>(
                    context: context,
                    builder: (context) => const ServerUrlUpdateDialog(),
                  );
                  if (shouldRetry == true) {
                    onRetry();
                  }
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

    final newSettings = settingsProvider.currentSettings.copyWith(
      localServerUrl: newUrl,
    );

    settingsProvider.updateSettings(newSettings);
    Navigator.of(context).pop(true);
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
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saveAndClose,
          child: const Text('Save & Retry'),
        ),
      ],
    );
  }
}
