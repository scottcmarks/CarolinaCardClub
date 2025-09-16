// client/lib/widgets/player_panel.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/payment.dart';
import '../models/player_selection_item.dart';
import '../models/session.dart';
import '../providers/api_provider.dart';
import '../providers/time_provider.dart';

class PlayerPanel extends StatelessWidget {
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
          return ListView.builder(
            key: const PageStorageKey<String>('PlayerListScrollPosition'),
            itemCount: players.length,
            itemBuilder: (context, index) {
              final player = players[index];
              return PlayerCard(
                player: player,
                isSelected: player.playerId == selectedPlayerId,
                onPlayerSelected: onPlayerSelected,
                onSessionAdded: onSessionAdded,
                clubSessionStartDateTime: clubSessionStartDateTime,
              );
            },
          );
        }
      },
    );
  }
}

class PlayerCard extends StatefulWidget {
  final PlayerSelectionItem player;
  final bool isSelected;
  final ValueChanged<int?>? onPlayerSelected;
  final ValueChanged<int>? onSessionAdded;
  final DateTime? clubSessionStartDateTime;

  const PlayerCard({
    super.key,
    required this.player,
    required this.isSelected,
    this.onPlayerSelected,
    this.onSessionAdded,
    this.clubSessionStartDateTime,
  });

  @override
  State<PlayerCard> createState() => _PlayerCardState();
}

class _PlayerCardState extends State<PlayerCard> {
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

      // Check if the widget is still mounted before calling the callback
      if (mounted) {
        widget.onSessionAdded?.call(newSessionId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting session: $e')),
        );
      }
    }
  }

  void _showAddMoneyDialog(BuildContext context, PlayerSelectionItem player,
      {required bool startSessionAfter}) {
    final TextEditingController amountController = TextEditingController();
    if (player.balance < 0) {
      amountController.text = (-player.balance).toStringAsFixed(2);
    }

    final apiProvider = Provider.of<ApiProvider>(context, listen: false);
    final timeProvider = Provider.of<TimeProvider>(context, listen: false);

    showDialog(
      context: context,
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

                    // Use dialogContext to pop
                    Navigator.of(dialogContext).pop();

                    if (startSessionAfter && updatedPlayer.balance >= 0) {
                      await _startNewSession(
                          apiProvider, timeProvider, updatedPlayer);
                    } else if (startSessionAfter) {
                      // Pass the original context for showing the next dialog
                      _showAddMoneyDialog(context, updatedPlayer,
                          startSessionAfter: true);
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to add payment: $e')),
                      );
                    }
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showPlayerMenu(BuildContext context) {
    // *** THE FIX IS HERE ***
    // Get the providers *before* calling showDialog, using the valid context.
    final apiProvider = Provider.of<ApiProvider>(context, listen: false);
    final timeProvider = Provider.of<TimeProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        final canStartSession = widget.clubSessionStartDateTime != null;

        if (widget.player.balance < 0) {
          return AlertDialog(
            backgroundColor: Colors.red.shade100,
            title: const Text('Negative Balance'),
            content: Text(
                'The current balance for ${widget.player.name} is negative.\nPlease add money to continue.'),
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
                    _showAddMoneyDialog(context, widget.player,
                        startSessionAfter: canStartSession);
                  }),
            ],
          );
        } else {
          return AlertDialog(
            backgroundColor: Colors.green.shade100,
            title: Text('Player Menu for ${widget.player.name}'),
            content: const Text('What would you like to do?'),
            actions: [
              if (canStartSession)
                TextButton(
                    child: const Text('Open a new session'),
                    onPressed: () async {
                      Navigator.of(dialogContext).pop();
                      // The captured providers are used here, which is safe.
                      await _startNewSession(
                          apiProvider, timeProvider, widget.player);
                    }),
              TextButton(
                  child: const Text('Add Money'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _showAddMoneyDialog(context, widget.player,
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
    Color? cardColor;
    if (widget.player.balance > 0) {
      cardColor = Colors.green.shade100;
    } else if (widget.player.balance < 0) {
      cardColor = Colors.red.shade100;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      color: cardColor,
      shape: widget.isSelected
          ? RoundedRectangleBorder(
              side:
                  BorderSide(color: Theme.of(context).primaryColor, width: 2.0),
              borderRadius: BorderRadius.circular(4.0),
            )
          : null,
      child: InkWell(
        onTap: () {
          if (widget.isSelected) {
            widget.onPlayerSelected?.call(null);
          } else {
            widget.onPlayerSelected?.call(widget.player.playerId);
            _showPlayerMenu(context);
          }
        },
        child: ListTile(
          title: Text(
            widget.player.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          // subtitle:
          //     Text('Balance: \$${widget.player.balance.toStringAsFixed(2)}'),
        ),
      ),
    );
  }
}