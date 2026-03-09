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

  Future<void> _toggleClubSession() async {
    final api = Provider.of<ApiProvider>(context, listen: false);
    final timeProvider = Provider.of<TimeProvider>(context, listen: false);
    final nowEpoch = timeProvider.nowEpoch;

    try {
      if (!api.isClubSessionOpen) {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Session Toggle Error: $e")),
        );
      }
    }
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

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 220,
        leading: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Image.asset('assets/CCCBannerA.png', fit: BoxFit.contain, alignment: Alignment.centerLeft),
        ),
        flexibleSpace: const Center(child: RealTimeClock()),
        elevation: 2,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onSelected: (value) async {
              switch (value) {
                case 'session':
                  await _toggleClubSession();
                case 'reload':
                  await _refreshData();
                case 'settings':
                  if (mounted) {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const SettingsPage()));
                  }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'session',
                child: Row(children: [
                  Icon(
                    api.isClubSessionOpen ? Icons.stop_circle_outlined : Icons.play_circle_outline,
                    color: api.isClubSessionOpen ? Colors.red : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(api.isClubSessionOpen ? 'Close Club Session' : 'Open Club Session'),
                ]),
              ),
              PopupMenuItem(
                value: 'reload',
                child: const Row(children: [
                  Icon(Icons.refresh),
                  SizedBox(width: 8),
                  Text('Reload'),
                ]),
              ),
              PopupMenuItem(
                value: 'settings',
                child: const Row(children: [
                  Icon(Icons.tune),
                  SizedBox(width: 8),
                  Text('More Settings'),
                ]),
              ),
            ],
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