// client/lib/pages/home_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/api_provider.dart';
import '../providers/time_provider.dart';
import '../widgets/player_panel.dart';
import '../widgets/session_panel.dart';
import '../widgets/real_time_clock.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    // Refresh data once the widget is mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  Future<void> _refreshData() async {
    final api = Provider.of<ApiProvider>(context, listen: false);
    try {
      await api.fetchTables();
      await api.fetchPlayers();
      await api.fetchSessions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Sync Error: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = Provider.of<ApiProvider>(context);
    final timeProvider = Provider.of<TimeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Carolina Card Club"),
        elevation: 2,
        actions: [
          // 1. GAME CLOCK BADGE
          // Visual feedback if a time offset is active (turns orange)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: timeProvider.offset != Duration.zero
                  ? Colors.orange.shade100
                  : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: timeProvider.offset != Duration.zero
                    ? Colors.orange
                    : Colors.blue.shade200,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: timeProvider.offset != Duration.zero
                      ? Colors.orange.shade900
                      : Colors.blue.shade900
                ),
                const SizedBox(width: 8),
                const RealTimeClock(),
              ],
            ),
          ),

          // 2. REFRESH BUTTON
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: "Refresh Server Data",
          ),

          // 3. CLUB SESSION TOGGLE
          // Uses Game Clock (TimeProvider) for session start epoch
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              children: [
                const Text("Club Session", style: TextStyle(fontSize: 13)),
                const SizedBox(width: 8),
                Switch(
                  value: api.isClubSessionOpen,
                  activeThumbColor: Colors.green,
                  onChanged: (val) async {
                    try {
                      if (val) {
                        // Use Game Clock for the start timestamp
                        final startEpoch = (timeProvider.currentTime.millisecondsSinceEpoch / 1000).round();
                        await api.startClubSession(startEpoch);
                      } else {
                        await api.stopClubSession();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Session Toggle Error: $e")),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),

          // 4. SETTINGS
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // Left Sidebar: Player Actions
          const SizedBox(
            width: 350,
            child: PlayerPanel(),
          ),

          const VerticalDivider(width: 1),

          // Right Content: Session List and History
          const Expanded(
            child: SessionPanel(),
          ),
        ],
      ),
    );
  }
}