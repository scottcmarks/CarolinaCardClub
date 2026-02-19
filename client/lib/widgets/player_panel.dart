// client/lib/widgets/player_panel.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/api_provider.dart';
import '../providers/app_settings_provider.dart';
import '../models/player_selection_item.dart';
import '../models/session.dart';
import '../models/app_settings.dart';
import 'start_session_dialog.dart';

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
              final isSelected = api.selectedPlayerId == player.playerId;

              return ListTile(
                selected: isSelected,
                selectedTileColor: Colors.blue.shade50,
                leading: CircleAvatar(child: Text(player.name[0])),
                title: Text(player.name),
                subtitle: Text("\$${player.balance}"),

                // 1. Dashboard Filter Selection
                onTap: () {
                  if (isSelected) {
                    api.selectPlayer(null); // Deselect
                  } else {
                    api.selectPlayer(player.playerId); // Select
                  }
                },

                // 2. Start Session Trigger
                trailing: IconButton(
                  icon: Icon(
                    Icons.play_circle_fill,
                    color: api.isClubSessionOpen ? Colors.green : Colors.grey.shade400,
                    size: 32
                  ),
                  tooltip: api.isClubSessionOpen ? "Seat Player" : "Open Club Session First",
                  onPressed: () {
                    // Prevent starting if the club session is closed
                    if (!api.isClubSessionOpen) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("You must open a Club Session before seating players."),
                          duration: Duration(seconds: 2),
                        )
                      );
                      return;
                    }

                    // Get current settings to check for Floor Manager
                    final settings = Provider.of<AppSettingsProvider>(context, listen: false).currentSettings;

                    // Floor Manager VIP Bypass
                    if (player.playerId == settings.floorManagerPlayerId) {
                      _autoSeatFloorManager(context, player, api, settings);
                    } else {
                      // Standard Player Dialog
                      showDialog(
                        context: context,
                        builder: (_) => StartSessionDialog(player: player),
                      );
                    }
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- SPECIAL FLOOR MANAGER LOGIC ---
  Future<void> _autoSeatFloorManager(
    BuildContext context,
    PlayerSelectionItem player,
    ApiProvider api,
    AppSettings settings
  ) async {
    final fmSession = Session(
      sessionId: 0,
      playerId: player.playerId,
      pokerTableId: settings.floorManagerReservedTable,
      seatNumber: settings.floorManagerReservedSeat,
      startEpoch: (DateTime.now().millisecondsSinceEpoch / 1000).round(),
      isPrepaid: false,
      prepayAmount: 0.0,
    );

    try {
      await api.addSession(fmSession);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Floor Manager ${player.name} auto-seated at Table ${settings.floorManagerReservedTable}, Seat ${settings.floorManagerReservedSeat}"),
            backgroundColor: Colors.blue.shade800,
          )
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to auto-seat Floor Manager: $e"))
        );
      }
    }
  }
}