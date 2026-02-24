// client/lib/widgets/connection_failed_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/api_provider.dart';
import '../providers/app_settings_provider.dart';
import 'server_settings_dialog.dart';
import 'subnet_scan_dialog.dart';

class ConnectionFailedWidget extends StatefulWidget {
  const ConnectionFailedWidget({super.key});

  @override
  State<ConnectionFailedWidget> createState() => _ConnectionFailedWidgetState();
}

class _ConnectionFailedWidgetState extends State<ConnectionFailedWidget> {
  // Use a static flag to ensure we only auto-scan once per app session
  static bool _hasAttemptedAutoScan = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasAttemptedAutoScan) {
        _hasAttemptedAutoScan = true;
        _showScanDialog(context);
      }
    });
  }

  // Removed the initialIp parameter entirely since the dialog doesn't need it
  void _showScanDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const SubnetScanDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final apiProvider = Provider.of<ApiProvider>(context);
    final settings = Provider.of<AppSettingsProvider>(context).currentSettings;
    final currentUrl = "http://${settings.serverIp}:${settings.serverPort}";

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off, size: 80, color: Colors.redAccent),
                const SizedBox(height: 24),
                Text(
                  'Connection Failed',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Could not reach server at:\n$currentUrl',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),

                const SizedBox(height: 32),

                // 1. Retry Connection
                FilledButton.icon(
                  onPressed: apiProvider.reloadServerDatabase,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry Connection'),
                ),
                const SizedBox(height: 16),

                // 2. Manual Scan Trigger
                OutlinedButton.icon(
                  onPressed: () => _showScanDialog(context),
                  icon: const Icon(Icons.radar),
                  label: const Text('Find Server on Network'),
                ),

                const SizedBox(height: 16),

                // 3. Manual Settings
                TextButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const ServerSettingsDialog(),
                    );
                  },
                  child: const Text('Configure Manually'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}