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
  late String _localPreferredTheme;
  late TextEditingController _remoteDatabaseUrlController;

  @override
  void initState() {
    super.initState();

    _appSettingsProvider = Provider.of<AppSettingsProvider>(context, listen: false);
    final settings = _appSettingsProvider.currentSettings;
    _localShowOnlyActiveSessions = settings.showOnlyActiveSessions;
    _defaultSessionStartTime = settings.defaultSessionStartTime;
    _localPreferredTheme = settings.preferredTheme;
    _remoteDatabaseUrlController =
        TextEditingController(text: settings.remoteDatabaseUrl);

    _timeProvider = Provider.of<TimeProvider>(context, listen: false);
    _clockTime = null;
  }

  @override
  void dispose() {
    _remoteDatabaseUrlController.dispose();
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

  // A helper function to show the time picker using bottom_picker with headerBuilder
  void _showSessionTimePicker(BuildContext context) {
    BottomPicker.time(
      headerBuilder: (context) => _buildPickerHeader('Set Default Session Start Time'),
      initialTime: Time(
        hours: _defaultSessionStartTime?.hour     ?? 19, // Carolina Card Club defaults
        minutes: _defaultSessionStartTime?.minute ?? 30,
      ),
      onSubmit: (pickedDateTime) {
        if (pickedDateTime is DateTime) {
          setState(() {
            _defaultSessionStartTime = TimeOfDay(hour: pickedDateTime.hour, minute: pickedDateTime.minute);
          });
        }
      },
      onDismiss: (pickedDateTime) {
        // This callback is triggered when the picker is dismissed without a submission.
        // If you need to perform an action on dismissal, place it here.
        // In this case, we do nothing.
      },
      use24hFormat: true,
      bottomPickerTheme: BottomPickerTheme.blue,
    ).show(context);
  }

  // A helper function to show the combined date and time picker using bottom_picker with headerBuilder
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
      onDismiss: (pickedDateTime) {
        // This callback is triggered when the picker is dismissed without a submission.
        // If you need to perform an action on dismissal, place it here.
        // In this case, we do nothing.
      },
      use24hFormat: true,
      bottomPickerTheme: BottomPickerTheme.blue,
    ).show(context);
  }

  @override
  Widget build(BuildContext context) {
    final datePart = DateFormat.yMMMd();
    final timePart = DateFormat('HH:mm');

    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Text(
            'App Settings',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          // Toggle for showing only active sessions
          SwitchListTile(
            title: const Text('Show Only Active Sessions'),
            value: _localShowOnlyActiveSessions,
            onChanged: (bool value) {
              setState(() {
                _localShowOnlyActiveSessions = value;
              });
            },
          ),
          // Button to set session start time
          ListTile(
            title: const Text('Default Session Start Time'),
            trailing: TextButton(
              onPressed: () => _showSessionTimePicker(context),
              child: Text(_defaultSessionStartTime?.format(context) ?? 'Not set'),
            ),
          ),
          // Button to set the clock using bottom_picker
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
          // Text field for remote database URL
          TextField(
            controller: _remoteDatabaseUrlController,
            decoration:
                const InputDecoration(labelText: 'Remote Database URL'),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () {
              final _now = DateTime.now();
              final clockOffset = _clockTime?.difference(_now);
              _appSettingsProvider.updateSettings(
                showOnlyActiveSessions: _localShowOnlyActiveSessions,
                defaultSessionStartTime: _defaultSessionStartTime,
                clockOffset: clockOffset,
                preferredTheme: _localPreferredTheme,
                remoteDatabaseUrl: _remoteDatabaseUrlController.text,
              );
              if (_clockTime != null) {
                _timeProvider.setTime(_clockTime!);
              }
              setState((){});
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Save Settings'),
          ),
        ],
      ),
    );
  }
}
