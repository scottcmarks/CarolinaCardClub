// client/lib/widgets/server_settings_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart'; // Correct import
import '../providers/api_provider.dart';

class ServerSettingsDialog extends StatelessWidget {
  const ServerSettingsDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final api = Provider.of<ApiProvider>(context);

    return AlertDialog(
      title: const Text("Server Maintenance"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.circle, color: api.isConnected ? Colors.green : Colors.red, size: 12),
            title: Text(api.isConnected ? "Connected" : "Disconnected"),
            subtitle: api.lastError != null ? Text(api.lastError!) : null,
          ),
          const Divider(),
          ElevatedButton.icon(
            icon: const Icon(Icons.cloud_upload),
            label: const Text("Trigger Remote Backup"),
            onPressed: api.isConnected ? () => _handleBackup(context, api) : null,
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.cloud_download),
            label: const Text("Trigger Remote Restore"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade900),
            onPressed: api.isConnected ? () => _handleRestore(context, api) : null,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
        if (!api.isConnected)
          TextButton(
            onPressed: () => api.retryConnection(),
            child: const Text("Retry Connection"),
          ),
      ],
    );
  }

  Future<void> _handleBackup(BuildContext context, ApiProvider api) async {
    try {
      await api.triggerRemoteBackup(Shared.remoteApiKey);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Backup successful")));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Backup failed: $e")));
    }
  }

  Future<void> _handleRestore(BuildContext context, ApiProvider api) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Restore?"),
        content: const Text("This will overwrite your local database with the remote copy."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Restore")),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await api.triggerRemoteRestore(Shared.remoteApiKey);
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Restore complete")));
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Restore failed: $e")));
      }
    }
  }
}