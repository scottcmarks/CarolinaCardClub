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
import 'settle_payment_dialog.dart'; // NEW: Import the payment dialog

class PlayerPanel extends StatelessWidget {
  const PlayerPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final api = Provider.of<ApiProvider>(context);
    final timeProvider = Provider.of<TimeProvider>(context);

    final nowEpoch = timeProvider.nowEpoch;
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
                    subtitle: Text("\$${api.getDynamicBalance(player, nowEpoch)}"),
                    onTap: () => api.selectPlayer(isSelected ? null : player.playerId),

                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.currency_exchange_outlined, color: Colors.blue.shade700),
                          tooltip: "Settle Balance",
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => SettlePaymentDialog(player: player),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.play_circle_fill, color: Colors.green),
                          tooltip: "Seat Player",
                          onPressed: () {
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
                      ],
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

    int startEpoch = timeProvider.nowEpoch;

    if (api.isClubSessionOpen && api.clubSessionStartEpoch != null) {
      if (api.clubSessionStartEpoch! > startEpoch) {
        startEpoch = api.clubSessionStartEpoch!;
      }
    }

    final fmSession = Session(
      sessionId: 0,
      playerId: player.playerId,
      pokerTableId: settings.floorManagerReservedTable,
      seatNumber: settings.floorManagerReservedSeat,
      startEpoch: startEpoch,
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