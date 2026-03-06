// client/lib/widgets/server_disconnect_dialog.dart

import 'dart:io';
import 'package:flutter/material.dart';
import '../pages/settings_page.dart';
import 'subnet_scan_dialog.dart';

class ServerDisconnectDialog extends StatelessWidget {
  final String rawError;
  final VoidCallback onRetry;

  const ServerDisconnectDialog({
    super.key,
    required this.rawError,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    // Attempt to grab just the first line of the ugly error for the debug print
    final shortError = rawError.split('\n').first.replaceAll('Exception: ', '');

    return AlertDialog(
      icon: const Icon(Icons.wifi_off_rounded, color: Colors.red, size: 48),
      title: const Text("Server Connection Lost"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "We lost contact with the Carolina Card Club server.\n\n"
            "Please ensure the server is actively running and your IP/Port settings are correct.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              shortError,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontFamily: 'monospace'),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => exit(0), // Instantly quits the macOS app
          style: TextButton.styleFrom(foregroundColor: Colors.red.shade800),
          child: const Text("Quit App"),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
              },
              child: const Text("Server Settings"),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => const SubnetScanDialog(),
                );
              },
              child: const Text("Find Server"),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                onRetry(); // Fire the retry function
              },
              child: const Text("Retry"),
            ),
          ],
        ),
      ],
    );
  }
}