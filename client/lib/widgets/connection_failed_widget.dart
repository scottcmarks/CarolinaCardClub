// client/lib/widgets/connection_failed_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/api_provider.dart';
import 'server_settings_dialog.dart';
import 'subnet_scan_dialog.dart';

class ConnectionFailedWidget extends StatefulWidget {
  const ConnectionFailedWidget({super.key});

  @override
  State<ConnectionFailedWidget> createState() => _ConnectionFailedWidgetState();
}

class _ConnectionFailedWidgetState extends State<ConnectionFailedWidget> {

  @override
  void initState() {
    super.initState();

    // Auto-trigger scan if we haven't tried yet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final apiProvider = Provider.of<ApiProvider>(context, listen: false);
      if (!apiProvider.hasAttemptedAutoScan) {
        debugPrint('ConnectionFailedWidget: Auto-triggering subnet scan...');
        apiProvider.markAutoScanAttempted();
        _showScanDialog(context, apiProvider.connectingUrl);
      }
    });
  }

  void _showScanDialog(BuildContext context, String? currentUrl) {
    showDialog(
      context: context,
      builder: (context) => SubnetScanDialog(
        initialBaseIp: _extractIp(currentUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final apiProvider = Provider.of<ApiProvider>(context);

    return Scaffold(
      // **FIX**: Wrap in Center -> SingleChildScrollView to prevent overflow in landscape
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min, // shrink to fit
              children: [
                const Icon(
                  Icons.signal_wifi_off,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 24),
                Text(
                  'Connection Failed',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  'Could not connect to:\n${apiProvider.connectingUrl}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 32),

                // 1. Retry Connection
                FilledButton.icon(
                  onPressed: apiProvider.retryConnection,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry Connection'),
                ),
                const SizedBox(height: 16),

                // 2. Manual Scan Trigger
                OutlinedButton.icon(
                  onPressed: () {
                     _showScanDialog(context, apiProvider.connectingUrl);
                  },
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

  String? _extractIp(String? url) {
    if (url == null) return null;
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (e) {
      return null;
    }
  }
}