import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:bottom_picker/bottom_picker.dart';

import '../models/app_settings.dart';
import '../providers/app_settings_provider.dart';
import '../providers/api_provider.dart';
import '../providers/time_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late AppSettingsProvider _appSettingsProvider;
  late TimeProvider _timeProvider;
  late TextEditingController _serverUrlController;
  late TextEditingController _apiKeyController;
  late TimeOfDay? _defaultSessionStartTime;
  late DateTime? _clockTime;
  late String _preferredTheme;

  @override
  void initState() {
    super.initState();
    _appSettingsProvider = Provider.of<AppSettingsProvider>(context, listen: false);
    final settings = _appSettingsProvider.currentSettings;
    _serverUrlController = TextEditingController(text: settings.localServerUrl);
    _apiKeyController = TextEditingController(text: settings.localServerApiKey);
    _defaultSessionStartTime = settings.defaultSessionStartTime;
    _preferredTheme = settings.preferredTheme;

    _timeProvider = Provider.of<TimeProvider>(context, listen: false);
    final currentOffset = _timeProvider.offset;
    _clockTime = currentOffset == Duration.zero ? null : _timeProvider.currentTime;
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _showSessionTimePicker(BuildContext context) {
    BottomPicker.time(
      pickerTitle: const Text(
        'Set Default Session Start Time',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
      ),
      initialTime: Time(
        hours: _defaultSessionStartTime?.hour ?? 19,
        minutes: _defaultSessionStartTime?.minute ?? 30,
      ),
      onSubmit: (pickedTime) {
        // THE NEW FIX: Use a post-frame callback to ensure the picker is
        // fully disposed before we call setState.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && pickedTime is DateTime) {
            setState(() {
              _defaultSessionStartTime = TimeOfDay(hour: pickedTime.hour, minute: pickedTime.minute);
            });
          }
        });
      },
      use24hFormat: true,
    ).show(context);
  }

  void _showCombinedDateTimePicker(BuildContext context) {
    BottomPicker.dateTime(
      pickerTitle: const Text(
        'Set Custom Clock Time',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
      ),
      initialDateTime: _clockTime ?? _timeProvider.currentTime,
      onSubmit: (pickedDateTime) {
        // THE NEW FIX: Use a post-frame callback here as well.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && pickedDateTime is DateTime) {
            setState(() {
              _clockTime = pickedDateTime;
            });
          }
        });
      },
      use24hFormat: true,
    ).show(context);
  }

  void _handleReloadDatabase() async {
    final apiProvider = Provider.of<ApiProvider>(context, listen: false);
    if (apiProvider.serverStatus != ServerStatus.connected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not connected to server.')),
        );
      }
      return;
    }

    try {
      await apiProvider.reloadServerDatabase();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Server database reload command sent.')),
        );
      }
    } catch (e) {
      if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final datePart = DateFormat.yMMMd();
    final timePart = DateFormat('HH:mm');

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'App Settings',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const Divider(),
          TextField(
            controller: _serverUrlController,
            decoration: const InputDecoration(labelText: 'Local Server URL'),
          ),
          TextField(
            controller: _apiKeyController,
            decoration: const InputDecoration(labelText: 'Local Server API Key'),
            obscureText: true,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Preferred Theme'),
            trailing: DropdownButton<String>(
              value: _preferredTheme,
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() { _preferredTheme = newValue; });
                }
              },
              items: <String>['light', 'dark']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value.substring(0, 1).toUpperCase() + value.substring(1)),
                );
              }).toList(),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Default Session Start Time'),
            trailing: TextButton(
              onPressed: () => _showSessionTimePicker(context),
              child: Text(_defaultSessionStartTime?.format(context) ?? 'Not set'),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Clock Time'),
            trailing: TextButton(
              onPressed: () => _showCombinedDateTimePicker(context),
              child: Text(
                _clockTime != null
                    ? '${datePart.format(_clockTime!)} ${timePart.format(_clockTime!)}'
                    : 'Use Real Time',
              ),
            ),
          ),
          if (_clockTime != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _clockTime = null;
                  });
                },
                child: const Text('Reset Clock to Real Time'),
              ),
            ),
          const Spacer(),
          ElevatedButton(
            onPressed: _handleReloadDatabase,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700),
            child: const Text('Force Server to Reload Database'),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              final newSettings = _appSettingsProvider.currentSettings.copyWith(
                localServerUrl: _serverUrlController.text,
                localServerApiKey: _apiKeyController.text,
                defaultSessionStartTime: _defaultSessionStartTime,
                preferredTheme: _preferredTheme,
              );
              _appSettingsProvider.updateSettings(newSettings);

              if (_clockTime != null) {
                _timeProvider.setTime(_clockTime!);
              } else {
                _timeProvider.reset();
              }

              if (mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Save and Close'),
          ),
        ],
      ),
    );
  }
}
