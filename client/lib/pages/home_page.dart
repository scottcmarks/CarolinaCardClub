// client/lib/pages/home_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/api_provider.dart';
import '../providers/time_provider.dart';
import '../widgets/player_panel.dart';
import '../widgets/session_panel.dart';
import '../widgets/real_time_clock.dart';
import '../widgets/server_disconnect_dialog.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  Future<void> _refreshData() async {
    final api = Provider.of<ApiProvider>(context, listen: false);
    final timeProvider = Provider.of<TimeProvider>(context, listen: false);

    try {
      await api.reloadAll(timeProvider.nowEpoch);
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => ServerDisconnectDialog(
            rawError: e.toString(),
            onRetry: () {
              _refreshData();
            },
          ),
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
        title: Image.asset('assets/CCCBanner.png', fit: BoxFit.contain),
        elevation: 2,
        actions: [
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

          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: "Refresh Server Data",
          ),

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
                    final nowEpoch = timeProvider.nowEpoch;

                    try {
                      if (val) {
                        await api.startClubSession(nowEpoch);
                      } else {
                        final bool? confirmed = await showDialog<bool>(
                          context: context,
                          builder: (BuildContext ctx) {
                            return AlertDialog(
                              title: const Text("Close Club Session?"),
                              content: const Text(
                                  "Are you sure you want to close the club session and end all table sessions?"),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text("Cancel"),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                                  child: const Text("OK"),
                                ),
                              ],
                            );
                          },
                        );

                        if (confirmed == true) {
                          await api.closeClubAndEndSessions(nowEpoch);
                        }
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
          const SizedBox(
            width: 350,
            child: PlayerPanel(),
          ),
          const VerticalDivider(width: 1),
          const Expanded(
            child: SessionPanel(),
          ),
        ],
      ),
    );
  }
}