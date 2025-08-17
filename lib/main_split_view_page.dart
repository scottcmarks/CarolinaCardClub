// main_split_view_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // If using Provider
import 'left_panel.dart'; // Import your new panels
import 'right_panel.dart';
import 'settings_page.dart'; // Your SettingsPage1
import 'session_filter_provider.dart'; // If using Provider
import 'app_settings.dart';          // Import AppSettings
import 'app_settings_provider.dart'; // Import AppSettingsProvider
import 'session_panel.dart';

class MainSplitViewPage extends StatefulWidget {
  const MainSplitViewPage({super.key});

  @override
  State<MainSplitViewPage> createState() => _MainSplitViewPageState();
}

class _MainSplitViewPageState extends State<MainSplitViewPage> {
  // Removed _showOnlyActiveSessions, now managed by AppSettingsProvider

  void _openSettingsBottomSheet() async {
    await showModalBottomSheet<void>( // No need for return value here, as provider handles update
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return const SettingsPage1(); // SettingsPage1 manages its own Provider update
      },
    );
    // UI will rebuild automatically because MainSplitViewPage and SessionPanel
    // are consuming AppSettingsProvider.
  }

  @override
  Widget build(BuildContext context) {
    // Listen to the AppSettingsProvider to get the current settings
    final appSettings = Provider.of<AppSettingsProvider>(context).currentSettings;

    return Scaffold(
      appBar: AppBar(title: const Text('Split View App')),
      body: Row(
        children: [
          Expanded(
            flex: 1,
            child: LeftPanel(onOpenSettings: _openSettingsBottomSheet),
          ),
          const VerticalDivider(width: 1.0),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                const Text('Right Panel'),
                // Displaying some settings for feedback
                Text('Showing Active Sessions Only: ${appSettings.showOnlyActiveSessions ? "Yes" : "No"}'),
                Text('Preferred Theme: ${appSettings.preferredTheme}'),
                Expanded(
                  // Pass the relevant setting down to SessionPanel
                  child: SessionPanel(showOnlyActiveSessions: appSettings.showOnlyActiveSessions),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
