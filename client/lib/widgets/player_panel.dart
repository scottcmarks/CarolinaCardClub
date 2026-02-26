// client/lib/widgets/player_panel.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/api_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/time_provider.dart';
import '../models/player_selection_item.dart';
import '../models/session.dart';
import '../models/app_settings.dart';
import 'start_session_dialog.dart';

class PlayerPanel extends StatelessWidget {
  const PlayerPanel({super.key});

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
          child: players.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    "No players found.\nCheck the debug console for network or parsing errors.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                ),
              )
            : ListView.builder(
                itemCount: players.length,
                itemBuilder: (ctx, i) {
                  final player = players[i];
                  final isSelected = api.selectedPlayerId == player.playerId;

                  return ListTile(
                    selected: isSelected,
                    selectedTileColor: Colors.blue.shade50,
                    leading: CircleAvatar(
                      child: Text(player.name.isNotEmpty ? player.name[0] : '?')
                    ),
                    title: Text(player.name),
                    subtitle: Text("\$${api.getDynamicBalance(player)}"),
                    onTap: () => api.selectPlayer(isSelected ? null : player.playerId),
                    trailing: IconButton(
                      icon: const Icon(Icons.play_circle_fill, color: Colors.green),
                      onPressed: () {
                        // 🛑 BLOCK IF CLUB IS CLOSED
                        if (!api.isClubSessionOpen) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Cannot seat player. Please start a Club Session first."),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                          return;
                        }

                        final settings = Provider.of<AppSettingsProvider>(context, listen: false).currentSettings;
                        if (player.playerId == settings.floorManagerPlayerId) {
                          _autoSeatFloorManager(context, player, api, settings);
                        } else {
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

  Future<void> _autoSeatFloorManager(
    BuildContext context,
    PlayerSelectionItem player,
    ApiProvider api,
    AppSettings settings
  ) async {
    final timeProvider = Provider.of<TimeProvider>(context, listen: false);

    final fmSession = Session(
      sessionId: 0,
      playerId: player.playerId,
      pokerTableId: settings.floorManagerReservedTable,
      seatNumber: settings.floorManagerReservedSeat,
      startEpoch: (timeProvider.currentTime.millisecondsSinceEpoch / 1000).round(),
      isPrepaid: false,
      prepayAmount: 0,
    );

    try {
      await api.addSession(fmSession);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }
}