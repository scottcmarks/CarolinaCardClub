// client/lib/widgets/player_panel.dart

import 'dart:math'; // Import for max()
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/api_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/time_provider.dart';
import '../models/player_selection_item.dart';
import '../models/payment.dart';
import '../models/session.dart';

class PlayerPanel extends StatelessWidget {
  final ValueChanged<int?>? onPlayerSelected;
  final ValueChanged<int>? onSessionAdded;
  final int? selectedPlayerId;
  final DateTime? clubSessionStartDateTime; // Receive from parent

  const PlayerPanel({
    super.key,
    this.onPlayerSelected,
    this.onSessionAdded,
    this.selectedPlayerId,
    this.clubSessionStartDateTime,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ApiProvider>(
      builder: (context, apiProvider, child) {
        if (!apiProvider.isServerAvailable) {
          return const Center(child: Text('Error: Could not connect to the local server.', style: TextStyle(color: Colors.red)));
        }
        return FutureBuilder<List<PlayerSelectionItem>>(
          future: apiProvider.fetchPlayerSelectionList(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No players found.'));
            } else {
              return ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final player = snapshot.data![index];
                  return PlayerCard(
                    player: player,
                    isSelected: player.playerId == selectedPlayerId,
                    onPlayerSelected: onPlayerSelected,
                    onSessionAdded: onSessionAdded,
                    clubSessionStartDateTime: clubSessionStartDateTime, // Pass down
                  );
                },
              );
            }
          },
        );
      },
    );
  }
}

class PlayerCard extends StatelessWidget {
  final PlayerSelectionItem player;
  final bool isSelected;
  final ValueChanged<int?>? onPlayerSelected;
  final ValueChanged<int>? onSessionAdded;
  final DateTime? clubSessionStartDateTime; // Receive from parent

  const PlayerCard({super.key, required this.player, required this.isSelected, this.onPlayerSelected, this.onSessionAdded, this.clubSessionStartDateTime});

  Future<void> _startNewSession(BuildContext context, int playerId) async {
    final apiProvider = Provider.of<ApiProvider>(context, listen: false);
    final timeProvider = Provider.of<TimeProvider>(context, listen: false);

    final currentTime = timeProvider.currentTime;
    DateTime effectiveStartTime = currentTime;

    // Use the later of the current time or the club session start time
    if (clubSessionStartDateTime != null && clubSessionStartDateTime!.isAfter(currentTime)) {
      effectiveStartTime = clubSessionStartDateTime!;
    }

    final newSession = Session(
      playerId: playerId,
      startEpoch: effectiveStartTime.millisecondsSinceEpoch ~/ 1000,
    );

    final newSessionId = await apiProvider.addSession(newSession);
    onSessionAdded?.call(newSessionId);
  }

  void _showAddMoneyDialog(BuildContext context, PlayerSelectionItem currentPlayer) {
    final TextEditingController amountController = TextEditingController();
    if (currentPlayer.balance < 0) {
      amountController.text = (-currentPlayer.balance).toStringAsFixed(2);
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Add Money for ${currentPlayer.name}'),
          content: TextField(
            controller: amountController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount', prefixText: '\$'),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
          ),
          actions: [
            TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(dialogContext).pop()),
            TextButton(
              child: const Text('OK'),
              onPressed: () async {
                final double? amount = double.tryParse(amountController.text);
                if (amount != null && amount != 0) {
                  final apiProvider = Provider.of<ApiProvider>(context, listen: false);
                  final timeProvider = Provider.of<TimeProvider>(context, listen: false);
                  final newPayment = Payment(
                    playerId: currentPlayer.playerId,
                    amount: amount,
                    epoch: timeProvider.currentTime.millisecondsSinceEpoch ~/ 1000,
                  );

                  final updatedPlayer = await apiProvider.addPayment(newPayment);

                  Navigator.of(dialogContext).pop();

                  if (updatedPlayer.balance >= 0) {
                    _startNewSession(context, updatedPlayer.playerId);
                  } else {
                    _showAddMoneyDialog(context, updatedPlayer);
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
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final appSettings = Provider.of<AppSettingsProvider>(context, listen: false);

        if (player.balance < 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pop();
            _showAddMoneyDialog(context, player);
          });
          return const SizedBox.shrink();
        }

        return AlertDialog(
          title: Text('Player Menu for ${player.name}'),
          content: const Text('What would you like to do?'),
          backgroundColor: player.balance > 0 ? Colors.green.shade100 : null,
          actions: [
            TextButton(
              child: const Text('Add Money'),
              onPressed: () {
                Navigator.of(context).pop();
                _showAddMoneyDialog(context, player);
              },
            ),
            if (appSettings.currentSettings.showOnlyActiveSessions)
              TextButton(
                child: const Text('Open a new session'),
                onPressed: () {
                  Navigator.of(context).pop();
                  _startNewSession(context, player.playerId);
                },
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Color? cardColor;
    if (player.balance > 0) cardColor = Colors.green.shade100;
    else if (player.balance < 0) cardColor = Colors.red.shade100;

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
          trailing: player.balance > 0 ? const Icon(Icons.check_circle, color: Colors.green) : player.balance < 0 ? const Icon(Icons.warning, color: Colors.red) : null,
        ),
      ),
    );
  }
}
