// client/lib/widgets/main_split_view_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Needed for FontFeature
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/time_provider.dart';
import 'player_panel.dart';
import 'session_panel.dart';
import 'settings_page.dart';

class MainSplitViewPage extends StatefulWidget {
  const MainSplitViewPage({super.key});

  @override
  _MainSplitViewPageState createState() => _MainSplitViewPageState();
}

class _MainSplitViewPageState extends State<MainSplitViewPage> {
  int? _selectedPlayerId;
  int? _selectedSessionId;
  int? _newlyAddedSessionId;

  void _onPlayerSelected(int? playerId) {
    setState(() {
      _selectedPlayerId = playerId;
      _selectedSessionId = null;
    });
  }

  void _onSessionSelected(int? sessionId) {
    setState(() {
      _selectedSessionId = sessionId;
    });
  }

  void _onSessionAdded(int sessionId) {
    setState(() {
      _newlyAddedSessionId = sessionId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.settings),
          tooltip: 'Settings',
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (context) => const SettingsPage(),
            );
          },
        ),
        title: Center(
          child: SizedBox(
            height: 40,
            child: Image.asset('assets/CCCBanner.png'),
          ),
        ),
        actions: const [
          // Wrap the clock in a SizedBox to give it a fixed width
          SizedBox(
            width: 100, // Fixed width for the clock
            child: RealTimeClock(),
          ),
          SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 1,
            child: PlayerPanel(
              selectedPlayerId: _selectedPlayerId,
              onPlayerSelected: _onPlayerSelected,
              onSessionAdded: _onSessionAdded,
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            flex: 2,
            child: SessionPanel(
              selectedPlayerId: _selectedPlayerId,
              selectedSessionId: _selectedSessionId,
              onSessionSelected: _onSessionSelected,
              newlyAddedSessionId: _newlyAddedSessionId,
            ),
          ),
        ],
      ),
    );
  }
}

/// A widget that displays the current time and updates every second.
class RealTimeClock extends StatelessWidget {
  const RealTimeClock({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TimeProvider>(
      builder: (context, timeProvider, child) {
        final String formattedTime = DateFormat('HH:mm:ss').format(timeProvider.currentTime);
        return Center(
          child: Text(
            formattedTime,
            style: const TextStyle(
              fontSize: 18,
              // Changed from FontWeight.bold to FontWeight.normal
              fontWeight: FontWeight.normal,
              // This font feature ensures that all numbers take up the same
              // amount of space, which prevents the "wiggling" effect.
              fontFeatures: [
                FontFeature.tabularFigures(),
              ],
            ),
          ),
        );
      },
    );
  }
}
