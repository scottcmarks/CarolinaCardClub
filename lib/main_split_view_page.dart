// main_split_view_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // If using Provider
import 'player_panel.dart'; // Import your new panels
import 'session_panel.dart';
import 'settings_page.dart'; // Your SettingsPage1
import 'session_filter_provider.dart'; // If using Provider
import 'app_settings.dart';          // Import AppSettings
import 'app_settings_provider.dart'; // Import AppSettingsProvider

class MainSplitViewPage extends StatefulWidget {
  const MainSplitViewPage({super.key});

  @override
  State<MainSplitViewPage> createState() => _MainSplitViewPageState();
}

class _MainSplitViewPageState extends State<MainSplitViewPage> {
  int? _selectedPlayerId = null;
  int? _selectedSessionId = null;

  void _handlePlayerSelected(int? playerId) {
//    debug_print('_handlePlayerSelected($playerId)');
    setState(() {
      _selectedPlayerId = _selectedPlayerId == playerId ? null : playerId;
      if (_selectedPlayerId != null) {
        print('Selected Player ID: $_selectedPlayerId');
      } else {
        print('No selected player');
        _selectedSessionId = null;
      }
    });
 }

 void _handleSessionSelected(int? sessionId) {
//    debug_print('_handleSessionSelected($sessionId)');
    setState(() {
      _selectedSessionId = sessionId;
    });
  }

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

    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/CCCBanner.png',
          fit: BoxFit.fill,
          height: kToolbarHeight,
        ),
        centerTitle: true,
      ),
      body: Row(
        children: [
          Expanded(
            flex: 1,
            child: PlayerPanel(
              onPlayerSelected: _handlePlayerSelected,
              selectedPlayerId: _selectedPlayerId,
            ),
          ),
          const VerticalDivider(width: 1.0),
          Expanded(
            flex: 2,
            child: SessionPanel(
              onSessionSelected: _handleSessionSelected,
              onOpenSettings: _openSettingsBottomSheet,
              selectedPlayerId: _selectedPlayerId,
              selectedSessionId: _selectedSessionId,
            ),
          ),
        ],
      ),
    );
  }
}
