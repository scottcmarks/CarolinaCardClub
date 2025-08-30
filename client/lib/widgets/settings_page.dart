import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:bottom_picker/bottom_picker.dart';
import 'package:bottom_picker/resources/arrays.dart';

import '../models/app_settings.dart';
import '../providers/app_settings_provider.dart';
import '../providers/time_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Local variables to hold temporary changes before applying
  late AppSettingsProvider _appSettingsProvider;
  late TimeProvider _timeProvider;
  late bool _localShowOnlyActiveSessions;
  late TimeOfDay? _defaultSessionStartTime;
  late DateTime? _clockTime;

  late TextEditingController _localServerUrlController;
  late TextEditingController _localServerApiKeyController;

  @override
  void initState() {
    super.initState();

    _appSettingsProvider = Provider.of<AppSettingsProvider>(context, listen: false);
    final settings = _appSettingsProvider.currentSettings;
    _localShowOnlyActiveSessions = settings.showOnlyActiveSessions;
    _defaultSessionStartTime = settings.defaultSessionStartTime;

    _localServerUrlController = TextEditingController(text: settings.localServerUrl);
    _localServerApiKeyController = TextEditingController(text: settings.localServerApiKey);

    _timeProvider = Provider.of<TimeProvider>(context, listen: false);
    _clockTime = null;
  }

  @override
  void dispose() {
    _localServerUrlController.dispose();
    _localServerApiKeyController.dispose();
    super.dispose();
  }

  // A helper function to show the time picker
  void _showSessionTimePicker(BuildContext context) {
    // CORRECTED: Use the 'pickerTitle' parameter with a Text widget.
    BottomPicker.time(
      pickerTitle: const Text(
        'Set Default Session Start Time',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
      onSubmit: (index) {
        if (index is DateTime) {
          setState(() {
            _defaultSessionStartTime = TimeOfDay(hour: index.hour, minute: index.minute);
          });
        }
      },
      initialTime: Time(
        hours: _defaultSessionStartTime?.hour ?? 19,
        minutes: _defaultSessionStartTime?.minute ?? 30,
      ),
      use24hFormat: true,
    ).show(context);
  }

  // A helper function to show the combined date and time picker
  void _showCombinedDateTimePicker(BuildContext context) {
    // CORRECTED: Use the 'pickerTitle' parameter with a Text widget.
    BottomPicker.dateTime(
      pickerTitle: const Text(
        'Set Clock Time',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
      onSubmit: (index) {
        if (index is DateTime) {
          setState(() {
            _clockTime = index;
          });
        }
      },
      initialDateTime: _clockTime ?? _timeProvider.currentTime,
      minDateTime: DateTime(2025, 7, 1),
      use24hFormat: true,
    ).show(context);
  }

  void _saveSettings() {
    final newSettings = _appSettingsProvider.currentSettings.copyWith(
      showOnlyActiveSessions: _localShowOnlyActiveSessions,
      defaultSessionStartTime: _defaultSessionStartTime,
      localServerUrl: _localServerUrlController.text,
      localServerApiKey: _localServerApiKeyController.text,
    );
    _appSettingsProvider.updateSettings(newSettings);

    if (_clockTime != null) {
      _timeProvider.setTime(_clockTime!);
    }

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings Saved')),
      );
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
        children: [
          const Text(
            'App Settings',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              children: [
                SwitchListTile(
                  title: const Text('Show Only Active Sessions'),
                  value: _localShowOnlyActiveSessions,
                  onChanged: (bool value) {
                    setState(() {
                      _localShowOnlyActiveSessions = value;
                    });
                  },
                ),
                ListTile(
                  title: const Text('Default Session Start Time'),
                  trailing: TextButton(
                    onPressed: () => _showSessionTimePicker(context),
                    child: Text(_defaultSessionStartTime?.format(context) ?? 'Not set'),
                  ),
                ),
                ListTile(
                  title: const Text('Clock Time'),
                  trailing: TextButton(
                    onPressed: () => _showCombinedDateTimePicker(context),
                    child: Text(
                      _clockTime != null
                          ? '${datePart.format(_clockTime!)} ${timePart.format(_clockTime!)}'
                          : 'Set Time',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Server Configuration', style: Theme.of(context).textTheme.titleLarge),
                const Divider(),
                TextFormField(
                  controller: _localServerUrlController,
                  decoration: const InputDecoration(labelText: 'Local Server URL'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _localServerApiKeyController,
                  decoration: const InputDecoration(labelText: 'Local Server API Key'),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _saveSettings,
            child: const Text('Save Settings'),
          ),
        ],
      ),
    );
  }
}
