// lib/widgets/player_panel.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/database_provider.dart';
import '../models/player_selection_item.dart';

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

  /// Shows a context-sensitive dialog with a colored background based on the player's balance.
  void _showPlayerMenu(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        List<Widget> actions = [];
        String title = 'Player Actions';
        Widget content;
        Color? dialogColor;

        // Determine dialog color based on balance
        if (player.balance > 0) {
          dialogColor = Colors.green.shade100;
        } else if (player.balance < 0) {
          dialogColor = Colors.red.shade100;
        } else {
          dialogColor = null; // Default white
        }

        // Build the dialog content and actions based on the player's balance
        if (player.balance < 0) {
          title = 'Negative Balance';
          content = Text('The current balance for ${player.name} is negative.\nPlease add money to continue.');
          actions.addAll([
            TextButton(
              child: const Text('Add Money'),
              onPressed: () {
                debugPrint('Action: Add Money for player ${player.name}');
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                // De-select the player and then close the dialog.
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
                debugPrint('Action: Add Money for player ${player.name}');
                Navigator.of(context).pop();
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
    // Determine card color based on balance
    Color? cardColor;
    if (player.balance > 0) {
      cardColor = Colors.green.shade100;
    } else if (player.balance < 0) {
      cardColor = Colors.red.shade100;
    } else {
      cardColor = null; // Use default white for zero balance
    }

    // Use a border for the selected card to provide visual feedback
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
            // If the player is already selected, deselect them.
            onPlayerSelected?.call(null);
          } else {
            // If the player is not selected, select them AND show the menu.
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
