// client/lib/widgets/player_panel.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/api_provider.dart';
import '../models/player_selection_item.dart';

class PlayerPanel extends StatelessWidget {
  const PlayerPanel({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final api = Provider.of<ApiProvider>(context);
    final players = api.players;

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text("Players", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: players.length,
            itemBuilder: (ctx, i) {
              final player = players[i];
              // Highlight the selected player
              final isSelected = api.selectedPlayerId == player.playerId;

              return ListTile(
                selected: isSelected,
                selectedTileColor: Colors.blue.shade50,
                leading: CircleAvatar(child: Text(player.name[0])),
                title: Text(player.name),
                subtitle: Text("\$${player.balance}"),
                onTap: () {
                  // Toggle Logic: Tap again to deselect
                  if (isSelected) {
                    api.selectPlayer(null);
                  } else {
                    api.selectPlayer(player.playerId);
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}