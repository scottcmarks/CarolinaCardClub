// client/lib/widgets/connection_failed_widget.dart

import 'package:flutter/material.dart';

class ConnectionFailedWidget extends StatelessWidget {
  final String errorMessage;
  final VoidCallback onRetry;
  // **NEW**: Add the onSettings callback
  final VoidCallback onSettings;

  const ConnectionFailedWidget({
    super.key,
    required this.errorMessage,
    required this.onRetry,
    // **NEW**: Require onSettings in the constructor
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Connection Failed',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // **MODIFICATION**: Wrap buttons in a Row for side-by-side placement
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // This is your original "Retry" button
                ElevatedButton(
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
                const SizedBox(width: 16),
                // **NEW**: The "Settings" button
                OutlinedButton(
                  onPressed: onSettings,
                  child: const Text('Settings'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}