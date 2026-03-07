// client/lib/widgets/player_panel.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/api_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/time_provider.dart';
import '../models/player_selection_item.dart';
import '../models/session.dart';
import '../models/app_settings.dart';
import 'settle_payment_dialog.dart';
import 'player_card.dart';
import '../pages/seating_flow_page.dart';

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

                  return PlayerCard(
                    player: player,
                    isSelected: isSelected,
                    onTap: () => api.selectPlayer(isSelected ? null : player.playerId),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 16.0),
                          child: Text(
                            "\$${api.getDynamicBalance(player, nowEpoch)}",
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
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
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SeatingFlowPage(player: player),
                                ),
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

    final int nowEpoch = timeProvider.nowEpoch;
    final int startEpoch = api.effectiveStartEpoch(nowEpoch);

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
      await api.addSession(fmSession, nowEpoch); // <-- nowEpoch injected here
      api.selectPlayer(player.playerId);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }
}