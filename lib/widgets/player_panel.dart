// lib/widgets/player_panel.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_settings_provider.dart';
import '../providers/database_provider.dart';
import '../providers/time_provider.dart';
import '../models/player_selection_item.dart';
import '../models/payment.dart';
import '../models/session.dart';

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
          case DatabaseLoadStatus.loadingAssets:
            return const Center(child: CircularProgressIndicator());
          case DatabaseLoadStatus.error:
            return const Center(child: Text('Error loading database.', style: TextStyle(color: Colors.red)));
          case DatabaseLoadStatus.loaded:
            return FutureBuilder<List<PlayerSelectionItem>>(
              future: databaseProvider.fetchPlayerSelectionList(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
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

  void _showAddMoneyDialog(BuildContext context, double currentBalance) {
    final TextEditingController amountController = TextEditingController();
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
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount', prefixText: '\$'),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
          ),
          actions: [
            TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop()),
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

  void _showPlayerMenu(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final appSettings = Provider.of<AppSettingsProvider>(context, listen: false);
        List<Widget> actions = [];
        String title;
        Widget content;
        Color? dialogColor;

        if (player.balance < 0) {
          title = 'Negative Balance';
          content = Text('The current balance for ${player.name} is negative.\nPlease add money to continue.');
          dialogColor = Colors.red.shade100;
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
        } else {
          title = 'Player Menu';
          content = Text('What would you like to do for ${player.name}?');
          dialogColor = player.balance > 0 ? Colors.green.shade100 : null;
          actions.add(
            TextButton(
              child: const Text('Add Money'),
              onPressed: () {
                Navigator.of(context).pop();
                _showAddMoneyDialog(context, player.balance);
              },
            ),
          );
          // Conditionally add the "Open a new session" button
          if (appSettings.currentSettings.showOnlyActiveSessions) {
            actions.add(
              TextButton(
                child: const Text('Open a new session'),
                onPressed: () {
                  final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
                  final timeProvider = Provider.of<TimeProvider>(context, listen: false);
                  final newSession = Session(
                    playerId: player.playerId,
                    startEpoch: timeProvider.currentTime.millisecondsSinceEpoch ~/ 1000,
                  );
                  dbProvider.addSession(newSession);
                  Navigator.of(context).pop();
                },
              ),
            );
          }
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
    }

    final Border? border = isSelected ? Border.all(color: Theme.of(context).primaryColor, width: 2) : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      color: cardColor,
      shape: border != null ? RoundedRectangleBorder(side: BorderSide(color: Theme.of(context).primaryColor, width: 2.0), borderRadius: BorderRadius.circular(4.0)) : null,
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
