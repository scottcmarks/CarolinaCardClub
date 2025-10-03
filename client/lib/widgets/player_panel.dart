// client/lib/widgets/player_panel.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/payment.dart';
import '../models/player_selection_item.dart';
import '../models/session.dart';
import '../providers/api_provider.dart';
import '../providers/time_provider.dart';

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
  State<PlayerPanel> createState() => _PlayerPanelState();
}

class _PlayerPanelState extends State<PlayerPanel> {
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting session: $e')),
      );
    }
  }

  // FIX: Removed BuildContext parameter. It will now use the State's own context.
  void _showAddMoneyDialog(
      ApiProvider apiProvider,
      TimeProvider timeProvider,
      PlayerSelectionItem player,
      {required bool startSessionAfter}) {
    final TextEditingController amountController = TextEditingController();
    if (player.balance < 0) {
      amountController.text = (-player.balance).toStringAsFixed(2);
    }

    showDialog(
      context: context, // Uses the stable context from _PlayerPanelState
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Add Money for ${player.name}'),
          content: TextField(
            controller: amountController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixText: '\$',
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
          ),
          actions: [
            TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(dialogContext).pop()),
            TextButton(
              child: const Text('OK'),
              onPressed: () async {
                final double? amount = double.tryParse(amountController.text);
                if (amount != null && amount > 0) {
                  final newPayment = Payment(
                    playerId: player.playerId,
                    amount: amount,
                    epoch:
                        timeProvider.currentTime.millisecondsSinceEpoch ~/ 1000,
                  );

                  try {
                    final updatedPlayer =
                        await apiProvider.addPayment(newPayment.toMap());

                    Navigator.of(dialogContext).pop();
                    if (!mounted) return;

                    if (startSessionAfter && updatedPlayer.balance >= 0) {
                      await _startNewSession(
                          apiProvider, timeProvider, updatedPlayer);
                    } else if (startSessionAfter) {
                      // FIX: Call no longer passes context
                      _showAddMoneyDialog(apiProvider, timeProvider,
                          updatedPlayer,
                          startSessionAfter: true);
                    }
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to add payment: $e')),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  // FIX: Removed BuildContext parameter.
  void _showPlayerMenu(PlayerSelectionItem player) {
    final apiProvider = Provider.of<ApiProvider>(context, listen: false);
    final timeProvider = Provider.of<TimeProvider>(context, listen: false);

    showDialog(
      context: context, // Uses the stable context from _PlayerPanelState
      builder: (BuildContext dialogContext) {
        final canStartSession = widget.clubSessionStartDateTime != null;

        if (player.balance < 0) {
          return AlertDialog(
            backgroundColor: Colors.red.shade100,
            title: const Text('Negative Balance'),
            content: Text(
                'The current balance for ${player.name} is negative.\nPlease add money to continue.'),
            actions: [
              TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    widget.onPlayerSelected?.call(null);
                    Navigator.of(dialogContext).pop();
                  }),
              TextButton(
                  child: const Text('Add Money'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    if (!mounted) return;
                    // FIX: Call no longer passes context
                    _showAddMoneyDialog(apiProvider, timeProvider,
                        player,
                        startSessionAfter: canStartSession);
                  }),
            ],
          );
        } else {
          return AlertDialog(
            backgroundColor: Colors.green.shade100,
            title: Text('Player Menu for ${player.name}'),
            content: const Text('What would you like to do?'),
            actions: [
              if (canStartSession)
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
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    if (!mounted) return;
                    // FIX: Call no longer passes context
                    _showAddMoneyDialog(apiProvider, timeProvider,
                        player,
                        startSessionAfter: false);
                  }),
            ],
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final apiProvider = Provider.of<ApiProvider>(context);

    if (apiProvider.connectionStatus == ConnectionStatus.connecting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (apiProvider.connectionStatus == ConnectionStatus.disconnected) {
      return const Center(
          child: Text('Disconnected from server.',
              style: TextStyle(color: Colors.red)));
    }

    return FutureBuilder<List<PlayerSelectionItem>>(
      future: apiProvider.fetchPlayerSelectionList(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(
              child: Text('Error loading players: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red)));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No players found.'));
        } else {
          List<PlayerSelectionItem> players = snapshot.data!;
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
      },
    );
  }
}

class PlayerCard extends StatelessWidget {
  final PlayerSelectionItem player;
  final bool isSelected;
  final VoidCallback onTap;

  const PlayerCard({
    super.key,
    required this.player,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color? cardColor;
    if (player.balance > 0) {
      cardColor = Colors.green.shade100;
    } else if (player.balance < 0) {
      cardColor = Colors.red.shade100;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      color: cardColor,
      shape: isSelected
          ? RoundedRectangleBorder(
              side:
                  BorderSide(color: Theme.of(context).primaryColor, width: 2.0),
              borderRadius: BorderRadius.circular(4.0),
            )
          : null,
      child: InkWell(
        onTap: onTap,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
          title: Text(
            player.name,
            style: Theme.of(context).textTheme.titleLarge,
            softWrap: false,
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}