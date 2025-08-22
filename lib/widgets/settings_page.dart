// settings_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_settings.dart';          // Import AppSettings

import '../providers/app_settings_provider.dart'; // Import AppSettingsProvider

class SettingsPage1 extends StatefulWidget {
  const SettingsPage1({super.key});

  @override
  State<SettingsPage1> createState() => _SettingsPage1State();
}

class _SettingsPage1State extends State<SettingsPage1> {
  // Local variables to hold temporary changes before applying
  late bool _localShowOnlyActiveSessions;
  late TimeOfDay? _localDefaultStartTime;
  late String _localPreferredTheme;
  late TextEditingController _remoteDatabaseUrlController; // For the new URL field

  @override
  void initState() {
    super.initState();
    // Initialize local variables from the current provider state
    final settings = Provider.of<AppSettingsProvider>(context, listen: false).currentSettings;
    _localShowOnlyActiveSessions = settings.showOnlyActiveSessions;
    _localDefaultStartTime = settings.defaultStartTime;
    _localPreferredTheme = settings.preferredTheme;
    _remoteDatabaseUrlController = TextEditingController(text: settings.remoteDatabaseUrl);
  }

  @override
  void dispose() {
    _remoteDatabaseUrlController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _localDefaultStartTime ?? TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return Center(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.7,
            child: child,
          ),
        );
      },
    );
    if (picked != null && picked != _localDefaultStartTime) {
      setState(() {
        _localDefaultStartTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7, // Example height
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Text(
            'App Settings',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SwitchListTile(
            title: const Text('Show only active sessions'),
            value: _localShowOnlyActiveSessions,
            onChanged: (bool newValue) {
              setState(() {
                _localShowOnlyActiveSessions = newValue;
              });
            },
          ),
          ListTile(
            title: const Text('Default Start Time'),
            subtitle: Text(
              _localDefaultStartTime?.format(context) ?? 'Not set',
            ),
            trailing: const Icon(Icons.access_time),
            onTap: () => _selectTime(context),
          ),
          // Example: Dropdown for theme selection
          ListTile(
            title: const Text('Preferred Theme'),
            trailing: DropdownButton<String>(
              value: _localPreferredTheme,
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _localPreferredTheme = newValue;
                  });
                }
              },
              items: <String>['light', 'dark', 'system']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
          // New: Remote Database URL
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: TextField(
              controller: _remoteDatabaseUrlController,
              decoration: const InputDecoration(
                labelText: 'Remote Database URL',
                border: OutlineInputBorder(),
              ),
              onChanged: (newValue) {
                // No need to call setState here, as we're using a TextEditingController
                // The value will be read directly from the controller on save
              },
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () {
              // Get the provider instance to update it
              final appSettingsProvider = Provider.of<AppSettingsProvider>(context, listen: false);

              // Update the provider with the new settings
              appSettingsProvider.updateSettings(
                showOnlyActiveSessions: _localShowOnlyActiveSessions,
                defaultStartTime: _localDefaultStartTime,
                preferredTheme: _localPreferredTheme,
                remoteDatabaseUrl: _remoteDatabaseUrlController.text, // Add the new field
              );

              Navigator.pop(context); // Close the bottom sheet
            },
            child: const Text('Save Settings'),
          ),
        ],
      ),
    );
  }
}
