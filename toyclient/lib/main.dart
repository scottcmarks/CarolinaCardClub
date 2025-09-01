// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/app_settings_provider.dart';
import 'providers/api_provider.dart'; // Import the new provider file

// --- Main App Setup ---

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
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
  final _customUrlController =
      TextEditingController(text: 'http://127.0.0.2:8080');

  @override
  void dispose() {
    _customUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = context.watch<ApiProvider>();
    final appSettings = context.watch<AppSettingsProvider>();
    final currentUrl = appSettings.settings.serverUrl;

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
              label: 'http://127.0.0.1:8080',
              value: currentUrl == 'http://127.0.0.1:8080' &&
                  (api.status == ConnectionStatus.connected ||
                      api.status == ConnectionStatus.connecting),
              status: api.status,
              isActiveUrl: currentUrl == 'http://127.0.0.1:8080',
              onChanged: (bool? selected) {
                final newUrl = 'http://127.0.0.1:8080';
                context.read<AppSettingsProvider>().setServerUrl(newUrl);
                if (selected ?? false) {
                  context.read<ApiProvider>().connect(newUrl);
                } else {
                  context.read<ApiProvider>().disconnect();
                }
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ConnectionCheckbox(
                  label: 'Custom URL:',
                  value: currentUrl == _customUrlController.text &&
                      (api.status == ConnectionStatus.connected ||
                          api.status == ConnectionStatus.connecting),
                  status: api.status,
                  isActiveUrl: currentUrl == _customUrlController.text,
                  onChanged: (bool? selected) {
                    final newUrl = _customUrlController.text;
                    context.read<AppSettingsProvider>().setServerUrl(newUrl);
                    if (selected ?? false) {
                      context.read<ApiProvider>().connect(newUrl);
                    } else {
                      context.read<ApiProvider>().disconnect();
                    }
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
            StatusIndicator(),
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
      // case ConnectionStatus.disconnecting:
      //   return Text('Status: Disconnecting ...',
      //       style: const TextStyle(color: Colors.orange, fontSize: 16));
      case ConnectionStatus.disconnected:
        return const Text('Status: Disconnected',
            style: TextStyle(fontSize: 16));
      case ConnectionStatus.failed:
        return Text('Status: Failed\nError: ${api.lastError}',
            style: const TextStyle(color: Colors.red, fontSize: 16));
    }
  }
}
