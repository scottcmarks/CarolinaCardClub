// client/lib/widgets/player_panel.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/player_selection_item.dart';
import '../models/session.dart';
import '../providers/api_provider.dart';
import '../providers/time_provider.dart';
import 'dialogs.dart';
import 'player_card.dart'; // **NEW IMPORT**

class PlayerPanel extends StatefulWidget {
  final int? selectedPlayerId;
  final ValueChanged<int?>? onPlayerSelected;
  final ValueChanged<int>? onSessionAdded;
  final DateTime? clubSessionStartDateTime;

  const PlayerPanel({
    super.key,
    this.selectedPlayerId,
    this.onPlayerSelected,
    this.onSessionAdded,
    this.clubSessionStartDateTime,
  });

  @override
  State<PlayerPanel> createState() => PlayerPanelState();
}

class PlayerPanelState extends State<PlayerPanel> {
  Future<void> _startNewSession(ApiProvider apiProvider,
      TimeProvider timeProvider, PlayerSelectionItem player) async {
    try {
      final now = timeProvider.currentTime;
      final sessionStart = widget.clubSessionStartDateTime != null &&
              now.isBefore(widget.clubSessionStartDateTime!)
          ? widget.clubSessionStartDateTime!
          : now;

      final newSession = Session(
        playerId: player.playerId,
        startEpoch: sessionStart.millisecondsSinceEpoch ~/ 1000,
      );
      final newSessionId = await apiProvider.addSession(newSession);

      if (!mounted) return;
      widget.onSessionAdded?.call(newSessionId);
      // Deselect the player after a session is successfully started.
      widget.onPlayerSelected?.call(null);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting session: $e')),
      );
    }
  }

  void _showPlayerMenu(PlayerSelectionItem player) {
    final apiProvider = Provider.of<ApiProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Consumer<TimeProvider>(
          builder: (context, timeProvider, child) {
            final double dynamicBalance = apiProvider.getDynamicBalance(
              playerId: player.playerId,
              currentTime: timeProvider.currentTime,
              clubSessionStartDateTime: widget.clubSessionStartDateTime,
            );

            final currencyFormatter =
                NumberFormat.currency(symbol: '\$', decimalDigits: 0);
            final formattedBalance = currencyFormatter.format(dynamicBalance);
            final titleText = '${player.name}: balance is $formattedBalance';

            final canStartSession = widget.clubSessionStartDateTime != null;

            if (dynamicBalance < 0) {
              return AlertDialog(
                backgroundColor: Colors.red.shade100,
                title: Text(titleText),
                content: const Text('Please add money to continue.'),
                actions: [
                  TextButton(
                      child: const Text('Cancel'),
                      onPressed: () {
                        // Only close the dialog, don't deselect the player.
                        Navigator.of(dialogContext).pop();
                      }),
                  TextButton(
                      child: const Text('Add Money'),
                      onPressed: () async {
                        Navigator.of(dialogContext).pop();

                        // Wait for the next frame to avoid gesture conflict
                        await Future.delayed(Duration.zero);

                        if (!mounted) return;
                        final updatedPlayer =
                            await showAddMoneyDialog(context, player: player);

                        if (updatedPlayer != null && mounted) {
                          _showPlayerMenu(updatedPlayer);
                        }
                      }),
                ],
              );
            } else {
              return AlertDialog(
                backgroundColor: Colors.green.shade100,
                title: Text(titleText),
                content: player.hasActiveSession
                    ? const Text('This player already has an active session.')
                    : const Text('What would you like to do?'),
                actions: [
                  if (canStartSession && !player.hasActiveSession)
                    TextButton(
                        child: const Text('Open a new session'),
                        onPressed: () async {
                          Navigator.of(dialogContext).pop();
                          if (!mounted) return;
                          await _startNewSession(
                              apiProvider, timeProvider, player);
                        }),
                  TextButton(
                      child: const Text('Add Money'),
                      onPressed: () async {
                        Navigator.of(dialogContext).pop();

                        await Future.delayed(Duration.zero);

                        if (!mounted) return;
                        final updatedPlayer =
                            await showAddMoneyDialog(context, player: player);

                        if (updatedPlayer != null && mounted) {
                          _showPlayerMenu(updatedPlayer);
                        }
                      }),
                ],
              );
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final apiProvider = context.watch<ApiProvider>();
    final players = apiProvider.players;

    if (players.isEmpty) {
      return const Center(child: Text('No players found.'));
    }

    return SingleChildScrollView(
      key: const PageStorageKey<String>('PlayerListScrollPosition'),
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: players.map((player) {
            return PlayerCard(
              player: player,
              isSelected: player.playerId == widget.selectedPlayerId,
              onTap: () {
                if (player.playerId == widget.selectedPlayerId) {
                  widget.onPlayerSelected?.call(null);
                } else {
                  widget.onPlayerSelected?.call(player.playerId);
                  _showPlayerMenu(player);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}