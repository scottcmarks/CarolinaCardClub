// client/lib/widgets/server_settings_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart';
import '../providers/app_settings_provider.dart';

class ServerSettingsDialog extends StatefulWidget {
  const ServerSettingsDialog({super.key});

  @override
  State<ServerSettingsDialog> createState() => _ServerSettingsDialogState();
}

class _ServerSettingsDialogState extends State<ServerSettingsDialog> {
  late TextEditingController _ipController;
  late TextEditingController _portController;

  @override
  void initState() {
    super.initState();
    final s = Provider.of<AppSettingsProvider>(context, listen: false).currentSettings;
    _ipController = TextEditingController(text: s.serverIp);
    _portController = TextEditingController(text: s.serverPort.toString());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Network Configuration'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _ipController, decoration: const InputDecoration(labelText: 'IP')),
          TextField(controller: _portController, decoration: const InputDecoration(labelText: 'Port'), keyboardType: TextInputType.number),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final provider = Provider.of<AppSettingsProvider>(context, listen: false);
            provider.updateSettings(provider.currentSettings.copyWith(
              serverIp: _ipController.text,
              serverPort: int.tryParse(_portController.text) ?? Shared.defaultServerPort,
            ));
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}