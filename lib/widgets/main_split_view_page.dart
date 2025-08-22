// main_split_view_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // If using Provider

import '../providers/app_settings_provider.dart';
import '../providers/session_filter_provider.dart';

import '../models/app_settings.dart';

import 'settings_page.dart';
import 'player_panel.dart';
import 'session_panel.dart';
import 'realtimeclock.dart';



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
        return const SettingsPage1();
      },
    );
    // UI will rebuild automatically because MainSplitViewPage and SessionPanel
    // are consuming AppSettingsProvider.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: _openSettingsBottomSheet,
          tooltip: 'Open Settings',
        ),
        title: Image.asset(
          'assets/CCCBanner.png',
          fit: BoxFit.fill,
          height: kToolbarHeight,
        ),
        centerTitle: true,
        actions: const [
          // Place widgets on the right side of the AppBar
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: RealtimeClock(),
          ),
        ],
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
              selectedPlayerId: _selectedPlayerId,
              selectedSessionId: _selectedSessionId,
            ),
          ),
        ],
      ),
    );
  }
}
