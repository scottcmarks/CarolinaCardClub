// client/lib/widgets/settings_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/api_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/time_provider.dart';
import 'server_settings_dialog.dart'; // **NEW IMPORT**
import 'set_clock_dialog.dart';       // **NEW IMPORT**

// Wrapper function kept to maintain compatibility with other files (e.g., connection_failed_widget.dart)
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
                  currentSettings.sessionStartTime?.format(context) ??
                      const TimeOfDay(hour: 19, minute: 30).format(context),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                leading: const Icon(Icons.access_time),
                onTap: () async {
                  final initialTime = currentSettings.sessionStartTime ??
                      const TimeOfDay(hour: 19, minute: 30);

                  final TimeOfDay? picked = await showTimePicker(
                    context: context,
                    initialTime: initialTime,
                  );

                  if (picked != null && picked != initialTime) {
                    final newSettings = currentSettings.copyWith(
                      sessionStartTime: picked,
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