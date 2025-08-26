// lib/widgets/player_panel.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/database_provider.dart';
import '../providers/time_provider.dart';
import '../models/player_selection_item.dart';
import '../models/payment.dart';

class PlayerPanel extends StatelessWidget {
  final ValueChanged<int?>? onPlayerSelected;
  final int? selectedPlayerId;

  const PlayerPanel({
    super.key,
    this.onPlayerSelected,
    this.selectedPlayerId,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<DatabaseProvider>(
      builder: (context, databaseProvider, child) {
        switch (databaseProvider.loadStatus) {
          case DatabaseLoadStatus.initial:
          case DatabaseLoadStatus.loadingRemote:
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text('Downloading database...'),
                ],
              ),
            );
          case DatabaseLoadStatus.loadingAssets:
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text('Loading database from assets...'),
                ],
              ),
            );
          case DatabaseLoadStatus.error:
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Failed to load database. Please check settings and internet connection.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red),
                ),
              ),
            );
          case DatabaseLoadStatus.loaded:
            return FutureBuilder<List<PlayerSelectionItem>>(
              future: databaseProvider.fetchPlayerSelectionList(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error loading players: ${snapshot.error}'));
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
                      );
                    },
                  );
                }
              },
            );
        }
      },
    );
  }
}

/// A card to display player information with a context menu on left-click.
class PlayerCard extends StatelessWidget {
  final PlayerSelectionItem player;
  final bool isSelected;
  final ValueChanged<int?>? onPlayerSelected;

  const PlayerCard({
    super.key,
    required this.player,
    required this.isSelected,
    this.onPlayerSelected,
  });

  /// Shows a dialog for adding a payment for the current player.
  void _showAddMoneyDialog(BuildContext context, double currentBalance) {
    final TextEditingController amountController = TextEditingController();
    // Pre-fill the amount if the balance is negative
    if (currentBalance < 0) {
      amountController.text = (-currentBalance).toStringAsFixed(2);
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add Money for ${player.name}'),
          content: TextField(
            controller: amountController,
            // Set autofocus to true
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
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                final double? amount = double.tryParse(amountController.text);
                if (amount != null && amount != 0) {
                  final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
                  final timeProvider = Provider.of<TimeProvider>(context, listen: false);

                  final newPayment = Payment(
                    playerId: player.playerId,
                    amount: amount,
                    epoch: timeProvider.currentTime.millisecondsSinceEpoch ~/ 1000,
                  );

                  dbProvider.addPayment(newPayment);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  /// Shows a context-sensitive dialog based on the player's balance.
  void _showPlayerMenu(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        List<Widget> actions = [];
        String title = 'Player Actions';
        Widget content;
        Color? dialogColor;

        if (player.balance > 0) {
          dialogColor = Colors.green.shade100;
        } else if (player.balance < 0) {
          dialogColor = Colors.red.shade100;
        } else {
          dialogColor = null; // Default white
        }

        if (player.balance < 0) {
          title = 'Negative Balance';
          content = Text('The current balance for ${player.name} is negative.\nPlease add money to continue.');
          actions.addAll([
            TextButton(
              child: const Text('Add Money'),
              onPressed: () {
                Navigator.of(context).pop();
                _showAddMoneyDialog(context, player.balance);
              },
            ),
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                onPlayerSelected?.call(null);
                Navigator.of(context).pop();
              },
            ),
          ]);
        } else { // Positive or zero balance
          title = 'Player Menu';
          content = Text('What would you like to do for ${player.name}?');
          actions.addAll([
            TextButton(
              child: const Text('Add Money'),
              onPressed: () {
                Navigator.of(context).pop();
                _showAddMoneyDialog(context, player.balance);
              },
            ),
            TextButton(
              child: const Text('Open a new session'),
              onPressed: () {
                debugPrint('Action: Open a new session for player ${player.name}');
                Navigator.of(context).pop();
              },
            ),
          ]);
        }

        return AlertDialog(
          backgroundColor: dialogColor,
          title: Text(title),
          content: content,
          actions: actions,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Color? cardColor;
    if (player.balance > 0) {
      cardColor = Colors.green.shade100;
    } else if (player.balance < 0) {
      cardColor = Colors.red.shade100;
    } else {
      cardColor = null;
    }

    final Border? border = isSelected
        ? Border.all(color: Theme.of(context).primaryColor, width: 2)
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      color: cardColor,
      shape: border != null ? RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).primaryColor, width: 2.0),
        borderRadius: BorderRadius.circular(4.0),
      ) : null,
      child: InkWell(
        onTap: () {
          if (isSelected) {
            onPlayerSelected?.call(null);
          } else {
            onPlayerSelected?.call(player.playerId);
            _showPlayerMenu(context);
          }
        },
        child: ListTile(
          title: Text(player.name),
          subtitle: Text('Balance: \$${player.balance.toStringAsFixed(2)}'),
          trailing: player.balance > 0
              ? const Icon(Icons.check_circle, color: Colors.green)
              : player.balance < 0
                  ? const Icon(Icons.warning, color: Colors.red)
                  : null,
        ),
      ),
    );
  }
}
