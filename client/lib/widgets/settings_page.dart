// client/lib/widgets/settings_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart';

import '../models/app_settings.dart';
import '../providers/api_provider.dart';
import '../providers/app_settings_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Server Settings'),
            subtitle: Text(
              'Configure the connection to the server',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            leading: const Icon(Icons.storage),
            onTap: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return const ServerSettingsDialog();
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class ServerSettingsDialog extends StatefulWidget {
  const ServerSettingsDialog({super.key});

  @override
  State<ServerSettingsDialog> createState() => _ServerSettingsDialogState();
}

class _ServerSettingsDialogState extends State<ServerSettingsDialog> {
  late TextEditingController _urlController;
  late TextEditingController _apiKeyController;
  late String _initialServerUrl;

  bool _isUrlChanged = false;

  @override
  void initState() {
    super.initState();
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);

    _initialServerUrl = appSettingsProvider.currentSettings.localServerUrl;
    _urlController = TextEditingController(text: _initialServerUrl);
    _apiKeyController = TextEditingController(
        text: appSettingsProvider.currentSettings.localServerApiKey);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final apiProvider = Provider.of<ApiProvider>(context, listen: false);

    return AlertDialog(
      title: const Text('Server Settings'),
      content: SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            TextFormField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                hintText: defaultServerUrl,
              ),
              onChanged: (currentText) {
                final hasChanged = currentText != _initialServerUrl;
                if (hasChanged != _isUrlChanged) {
                  setState(() {
                    _isUrlChanged = hasChanged;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'API Key',
              ),
              obscureText: true,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        FilledButton(
          onPressed: () {
            final newSettings = AppSettings(
              localServerUrl: _urlController.text,
              localServerApiKey: _apiKeyController.text,
              preferredTheme:
                  appSettingsProvider.currentSettings.preferredTheme,
            );

            appSettingsProvider.updateSettings(newSettings);
            apiProvider.connect();

            Navigator.of(context).pop();
          },
          child: Text(_isUrlChanged ? 'Save' : 'Retry'),
        ),
      ],
    );
  }
}