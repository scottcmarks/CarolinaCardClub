// client/lib/widgets/settings_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart';

import '../models/app_settings.dart';
import '../providers/api_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/time_provider.dart';

Future<void> showServerSettingsDialog(BuildContext context) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return const ServerSettingsDialog();
    },
  );
}

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
              showServerSettingsDialog(context);
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Set Clock'),
            subtitle: Text(
              'Adjust the displayed date and time',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            leading: const Icon(Icons.schedule),
            onTap: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return const SetClockDialog();
                },
              );
            },
          ),
          const Divider(),
          // **NEW THEME SWITCH**
          Consumer<AppSettingsProvider>(
            builder: (context, appSettings, _) {
              final isDarkMode =
                  appSettings.currentSettings.preferredTheme == 'dark';
              return ListTile(
                leading: const Icon(Icons.brightness_6),
                title: const Text('Theme'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Light'),
                    Switch(
                      value: isDarkMode,
                      onChanged: (isDark) {
                        final currentSettings = appSettings.currentSettings;
                        final newSettings = AppSettings(
                          // Set the new theme value
                          preferredTheme: isDark ? 'dark' : 'light',
                          // Copy existing settings
                          localServerUrl: currentSettings.localServerUrl,
                          localServerApiKey: currentSettings.localServerApiKey,
                        );
                        // Update the provider, which will notify listeners and rebuild the UI
                        appSettings.updateSettings(newSettings);
                      },
                    ),
                    const Text('Dark'),
                  ],
                ),
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
            apiProvider.retryConnection();
            Navigator.of(context).pop();
          },
          child: Text(_isUrlChanged ? 'Save & Reconnect' : 'Retry'),
        ),
      ],
    );
  }
}

class SetClockDialog extends StatefulWidget {
  const SetClockDialog({super.key});

  @override
  State<SetClockDialog> createState() => _SetClockDialogState();
}

class _SetClockDialogState extends State<SetClockDialog> {
  late TextEditingController _timeController;
  late DateTime _initialTime;
  final DateFormat _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  @override
  void initState() {
    super.initState();
    final timeProvider = Provider.of<TimeProvider>(context, listen: false);

    _initialTime = timeProvider.currentTime;

    _timeController =
        TextEditingController(text: _dateTimeFormat.format(_initialTime));
  }

  @override
  void dispose() {
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeProvider = Provider.of<TimeProvider>(context, listen: false);

    return AlertDialog(
      title: const Text('Set Clock'),
      content: TextFormField(
        controller: _timeController,
        decoration: const InputDecoration(
          labelText: 'Date & Time (yyyy-MM-dd HH:mm:ss)',
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        FilledButton(
          child: const Text('Set'),
          onPressed: () {
            try {
              final newTime = _dateTimeFormat.parse(_timeController.text);

              final difference = newTime.difference(_initialTime);
              final currentOffset = timeProvider.offset;
              final newTotalOffset = currentOffset + difference;
              timeProvider.setOffset(newTotalOffset);

              Navigator.of(context).pop();
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: Colors.red,
                  content:
                      Text('Invalid format. Please use yyyy-MM-dd HH:mm:ss.'),
                ),
              );
            }
          },
        ),
      ],
    );
  }
}