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
    final apiProvider = Provider.of<ApiProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer<AppSettingsProvider>(
        builder: (context, appSettingsProvider, child) {
          final currentSettings = appSettingsProvider.currentSettings;

          return ListView(
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
                title: const Text('Revert Changes and Reload from Cloud'),
                subtitle: Text(
                  'Overwrite server data with the latest cloud backup',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                leading: const Icon(Icons.cloud_download),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext dialogContext) {
                      return AlertDialog(
                        title: const Text('Revert and Reload?'),
                        content: const Text(
                            'This will replace all current server data with the last cloud backup. Are you sure?'),
                        actions: [
                          TextButton(
                            child: const Text('Cancel'),
                            onPressed: () => Navigator.of(dialogContext).pop(),
                          ),
                          FilledButton(
                            child: const Text('Load'),
                            onPressed: () async {
                              final scaffoldMessenger =
                                  ScaffoldMessenger.of(context);
                              final rootNavigator = Navigator.of(context);

                              Navigator.of(dialogContext).pop();
                              rootNavigator.pop();

                              try {
                                await apiProvider.reloadServerDatabase();
                                scaffoldMessenger.showSnackBar(
                                  const SnackBar(
                                    backgroundColor: Colors.green,
                                    content: Text(
                                        'Successfully loaded data from cloud.'),
                                  ),
                                );
                              } catch (e) {
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    backgroundColor: Colors.red,
                                    content:
                                        Text('Failed to load from cloud: $e'),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              const Divider(),
              ListTile(
                title: const Text('Save Current State'),
                subtitle: Text(
                  'Uploads the current server data to the cloud backup',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                leading: const Icon(Icons.cloud_upload),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext dialogContext) {
                      return AlertDialog(
                        title: const Text('Save to Cloud?'),
                        content: const Text(
                            'This will overwrite the last cloud backup with the current server data. Are you sure?'),
                        actions: [
                          TextButton(
                            child: const Text('Cancel'),
                            onPressed: () => Navigator.of(dialogContext).pop(),
                          ),
                          FilledButton(
                            child: const Text('Save'),
                            onPressed: () async {
                              final scaffoldMessenger =
                                  ScaffoldMessenger.of(context);
                              final rootNavigator = Navigator.of(context);

                              Navigator.of(dialogContext).pop();
                              rootNavigator.pop();

                              try {
                                await apiProvider.backupDatabase();
                                scaffoldMessenger.showSnackBar(
                                  const SnackBar(
                                    backgroundColor: Colors.green,
                                    content: Text(
                                        'Successfully saved data to cloud.'),
                                  ),
                                );
                              } catch (e) {
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    backgroundColor: Colors.red,
                                    content:
                                        Text('Failed to save to cloud: $e'),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              const Divider(),
              ListTile(
                title: const Text('Default Session Start Time'),
                subtitle: Text(
                  currentSettings.defaultSessionStartTime?.format(context) ??
                      const TimeOfDay(hour: 19, minute: 30).format(context),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                leading: const Icon(Icons.access_time),
                onTap: () async {
                  final initialTime = currentSettings.defaultSessionStartTime ??
                      const TimeOfDay(hour: 19, minute: 30);

                  final TimeOfDay? picked = await showTimePicker(
                    context: context,
                    initialTime: initialTime,
                  );

                  if (picked != null && picked != initialTime) {
                    final newSettings = currentSettings.copyWith(
                      defaultSessionStartTime: picked,
                    );
                    appSettingsProvider.updateSettings(newSettings);
                  }
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
              ListTile(
                leading: const Icon(Icons.brightness_6),
                title: const Text('Theme'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Light'),
                    Switch(
                      value: currentSettings.preferredTheme == 'dark',
                      onChanged: (isDark) {
                        final newSettings = currentSettings.copyWith(
                          preferredTheme: isDark ? 'dark' : 'light',
                        );
                        appSettingsProvider.updateSettings(newSettings);
                      },
                    ),
                    const Text('Dark'),
                  ],
                ),
              ),
            ],
          );
        },
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
            final currentSettings = appSettingsProvider.currentSettings;

            // Update settings using copyWith to preserve other fields
            final newSettings = currentSettings.copyWith(
              localServerUrl: _urlController.text,
              localServerApiKey: _apiKeyController.text,
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
