// client/lib/pages/home_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/player_panel.dart';
import '../widgets/session_panel.dart';
import '../widgets/server_settings_dialog.dart';
import 'settings_page.dart';
import '../providers/api_provider.dart';

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Carolina Card Club"),
        actions: [
          // Club Session Toggle
          Consumer<ApiProvider>(
            builder: (ctx, api, _) => Switch(
              value: api.isClubSessionOpen,
              onChanged: (val) => api.toggleClubSession(),
              activeColor: Colors.green,
              inactiveThumbColor: Colors.red,
            ),
          ),
          const SizedBox(width: 8),

          IconButton(
            icon: const Icon(Icons.dns),
            tooltip: "Server Maintenance",
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const ServerSettingsDialog()
            ),
          ),

          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: "Settings",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage())
            ),
          ),
        ],
      ),
      // FIX: CrossAxisAlignment.stretch forces full height
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Panel (Player Selection) - 1/3 width
          Expanded(
            flex: 1,
            child: Container(
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: Colors.grey.shade300)),
              ),
              child: const PlayerPanel(),
            ),
          ),

          // Right Panel (Session Management) - 2/3 width
          const Expanded(
            flex: 2,
            child: SessionPanel(),
          ),
        ],
      ),
    );
  }
}