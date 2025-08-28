// client/lib/widgets/settings_page.dart

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

  // Updated controllers for new settings
  late TextEditingController _localServerUrlController;
  late TextEditingController _localServerApiKeyController;

  @override
  void initState() {
    super.initState();

    _appSettingsProvider = Provider.of<AppSettingsProvider>(context, listen: false);
    final settings = _appSettingsProvider.currentSettings;
    _localShowOnlyActiveSessions = settings.showOnlyActiveSessions;
    _defaultSessionStartTime = settings.defaultSessionStartTime;

    // Initialize new controllers
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

  /// Builds a standard title widget for the header of the bottom picker.
  Widget _buildPickerHeader(String title) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }

  // A helper function to show the time picker
  void _showSessionTimePicker(BuildContext context) {
    BottomPicker.time(
      headerBuilder: (context) => _buildPickerHeader('Set Default Session Start Time'),
      initialTime: Time(
        hours: _defaultSessionStartTime?.hour     ?? 19,
        minutes: _defaultSessionStartTime?.minute ?? 30,
      ),
      onSubmit: (pickedDateTime) {
        if (pickedDateTime is DateTime) {
          setState(() {
            _defaultSessionStartTime = TimeOfDay(hour: pickedDateTime.hour, minute: pickedDateTime.minute);
          });
        }
      },
      use24hFormat: true,
      bottomPickerTheme: BottomPickerTheme.blue,
    ).show(context);
  }

  // A helper function to show the combined date and time picker
  void _showCombinedDateTimePicker(BuildContext context) {
    BottomPicker.dateTime(
      headerBuilder: (context) => _buildPickerHeader('Set Clock Time'),
      initialDateTime: _clockTime ?? _timeProvider.currentTime,
      minDateTime: DateTime(2025, 7, 1),
      onSubmit: (pickedDateTime) {
        if (pickedDateTime is DateTime) {
          setState(() {
            _clockTime = pickedDateTime;
          });
        }
      },
      use24hFormat: true,
      bottomPickerTheme: BottomPickerTheme.blue,
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
