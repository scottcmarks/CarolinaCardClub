import 'package:flutter/material.dart';
import 'player_panel.dart';
import 'session_panel.dart';

class MainSplitViewPage extends StatefulWidget {
  const MainSplitViewPage({super.key});

  @override
  _MainSplitViewPageState createState() => _MainSplitViewPageState();
}

class _MainSplitViewPageState extends State<MainSplitViewPage> {
  int? _selectedPlayerId;
  int? _selectedSessionId;

  void _onPlayerSelected(int? playerId) {
    setState(() {
      _selectedPlayerId = playerId;
      _selectedSessionId = null; // Clear session selection when player changes
    });
  }

  void _onSessionSelected(int? sessionId) {
    setState(() {
      _selectedSessionId = sessionId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carolina Card Club'),
      ),
      body: Row(
        children: [
          // Left Panel
          Expanded(
            flex: 1,
            child: PlayerPanel(
              selectedPlayerId: _selectedPlayerId,
              onPlayerSelected: _onPlayerSelected,
            ),
          ),
          const VerticalDivider(width: 1),
          // Right Panel
          Expanded(
            flex: 2,
            child: SessionPanel(
              selectedPlayerId: _selectedPlayerId,
              selectedSessionId: _selectedSessionId,
              onSessionSelected: _onSessionSelected,
            ),
          ),
        ],
      ),
    );
  }
}
