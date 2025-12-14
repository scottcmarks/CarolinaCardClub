// client/lib/widgets/main_split_view_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/time_provider.dart';

import 'player_panel.dart';
import 'session_panel.dart';
import 'settings_page.dart';

class MainSplitViewPage extends StatefulWidget {
  const MainSplitViewPage({super.key});

  @override
  MainSplitViewPageState createState() => MainSplitViewPageState();
}

class MainSplitViewPageState extends State<MainSplitViewPage> {
  int? _selectedPlayerId;
  int? _selectedSessionId;
  int? _newlyAddedSessionId;
  DateTime? _clubSessionStartDateTime;

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

  void _onClubSessionTimeChanged(DateTime? newTime) {
    setState(() {
      _clubSessionStartDateTime = newTime;
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
          SizedBox(
            width: 100,
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
              clubSessionStartDateTime: _clubSessionStartDateTime,
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            flex: 2,
            child: SessionPanel(
              selectedPlayerId: _selectedPlayerId,
              selectedSessionId: _selectedSessionId,
              onSessionSelected: _onSessionSelected,
              // **MODIFICATION**: Pass the onPlayerSelected callback down.
              onPlayerSelected: _onPlayerSelected,
              newlyAddedSessionId: _newlyAddedSessionId,
              clubSessionStartDateTime: _clubSessionStartDateTime,
              onClubSessionTimeChanged: _onClubSessionTimeChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class RealTimeClock extends StatelessWidget {
  const RealTimeClock({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TimeProvider>(
      builder: (context, timeProvider, child) {
        final String formattedTime =
            DateFormat('HH:mm:ss').format(timeProvider.currentTime);
        return Center(
          child: Text(
            formattedTime,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.normal,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        );
      },
    );
  }
}
