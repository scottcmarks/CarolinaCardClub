// client/lib/widgets/main_split_view_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/api_provider.dart';
import 'player_panel.dart'; // Ensure this matches your filename
import 'session_panel.dart'; // Ensure this matches your filename

class MainSplitViewPage extends StatefulWidget {
  const MainSplitViewPage({Key? key}) : super(key: key);

  @override
  State<MainSplitViewPage> createState() => _MainSplitViewPageState();
}

class _MainSplitViewPageState extends State<MainSplitViewPage> {
  // We don't need _selectedPlayerId logic here anymore
  // because the PlayerPanel handles its own taps internally now.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Carolina Card Club"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Manual Refresh
              Provider.of<ApiProvider>(context, listen: false).reloadServerDatabase();
            },
          )
        ],
      ),
      body: Row(
        children: [
          // Left Panel: Player List
          const Expanded(
            flex: 1,
            // ERROR FIX: Removed selectedPlayerId parameter
            child: PlayerPanel(),
          ),

          const VerticalDivider(width: 1),

          // Right Panel: Session List
          const Expanded(
            flex: 2,
             // ERROR FIX: Removed selectedPlayerId parameter
            child: SessionPanel(),
          ),
        ],
      ),
    );
  }
}