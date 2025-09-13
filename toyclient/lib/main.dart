// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart';

import 'providers/app_settings_provider.dart';
import 'providers/api_provider.dart';
import 'package:db_connection/db_connection.dart';

// --- Main App Setup ---

void main() {
  // ensureInitialized is needed for async operations before runApp
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
        // The proxy provider now constructs our new, leaner ApiProvider
        ChangeNotifierProxyProvider<AppSettingsProvider, ApiProvider>(
          create: (context) => ApiProvider(context.read<AppSettingsProvider>()),
          update: (_, appSettings, previousApiProvider) {
            previousApiProvider?.updateAppSettings(appSettings);
            return previousApiProvider!;
          },
        ),
      ],
      child: const ToyClientApp(),
    ),
  );
}

class ToyClientApp extends StatelessWidget {
  const ToyClientApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ConnectionPage(),
    );
  }
}

// --- UI (View) ---

class ConnectionPage extends StatefulWidget {
  const ConnectionPage({super.key});

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  final _customUrlController = TextEditingController();

  @override
  void dispose() {
    _customUrlController.dispose();
    super.dispose();
  }

  /// This handler is now even simpler thanks to the new setServerUrl method.
  void _handleConnectionChange(String newUrl, bool selected) {
    final settingsProvider = context.read<AppSettingsProvider>();
    settingsProvider.setServerUrl(selected ? newUrl : '');
  }

  @override
  Widget build(BuildContext context) {
    final api = context.watch<ApiProvider>();
    final appSettings = context.watch<AppSettingsProvider>();

    // Show a loading screen until the initial settings are loaded from storage.
    if (appSettings.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Toy WebSocket Client')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Use the 'currentSettings' getter
    final currentUrl = appSettings.currentSettings.serverUrl;

    // Sync the controller's text with the loaded settings.
    if (currentUrl != defaultServerUrl &&
        _customUrlController.text != currentUrl) {
      _customUrlController.text = currentUrl;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Toy WebSocket Client')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select server to connect:',
                style: TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            ConnectionCheckbox(
              label: defaultServerUrl,
              value: currentUrl == defaultServerUrl &&
                  (api.status == ConnectionStatus.connected ||
                      api.status == ConnectionStatus.connecting),
              status: api.status,
              isActiveUrl: currentUrl == defaultServerUrl,
              onChanged: (bool? selected) {
                _handleConnectionChange(defaultServerUrl, selected ?? false);
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ConnectionCheckbox(
                  label: 'Custom URL:',
                  value: currentUrl == _customUrlController.text &&
                      currentUrl.isNotEmpty &&
                      (api.status == ConnectionStatus.connected ||
                          api.status == ConnectionStatus.connecting),
                  status: api.status,
                  isActiveUrl: currentUrl == _customUrlController.text,
                  onChanged: (bool? selected) {
                    _handleConnectionChange(
                        _customUrlController.text, selected ?? false);
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _customUrlController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onSubmitted: (newUrl) {
                      // Allow connecting by pressing Enter in the text field
                      _handleConnectionChange(newUrl, true);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            const Text('Connection Status:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const StatusIndicator(),
          ],
        ),
      ),
    );
  }
}

class ConnectionCheckbox extends StatelessWidget {
  final String label;
  final bool value;
  final ConnectionStatus status;
  final bool isActiveUrl;
  final ValueChanged<bool?> onChanged;

  const ConnectionCheckbox({
    super.key,
    required this.label,
    required this.value,
    required this.status,
    required this.isActiveUrl,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Color? color;
    if (isActiveUrl && status == ConnectionStatus.failed) {
      color = Colors.red;
    }

    return Row(
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor: color,
        ),
        Text(label, style: TextStyle(color: color, fontSize: 16)),
      ],
    );
  }
}

class StatusIndicator extends StatelessWidget {
  const StatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.watch<ApiProvider>();

    switch (api.status) {
      case ConnectionStatus.connected:
        return const Text('Status: Connected',
            style: TextStyle(color: Colors.green, fontSize: 16));
      case ConnectionStatus.connecting:
        return Row(
          children: [
            const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 8),
            Text('Status: Connecting to ${api.connectingUrl}...',
                style: const TextStyle(fontSize: 16)),
          ],
        );
      case ConnectionStatus.disconnected:
        return const Text('Status: Disconnected',
            style: TextStyle(fontSize: 16));
      case ConnectionStatus.failed:
        return Text('Status: Failed\nError: ${api.lastError}',
            style: const TextStyle(color: Colors.red, fontSize: 16));
    }
  }
}
