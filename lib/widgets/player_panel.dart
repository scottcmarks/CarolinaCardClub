// lib/widgets/player_panel.dart

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

/// A card to display player information.
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

  @override
  Widget build(BuildContext context) {
    Color? cardColor;

    if (isSelected) {
      if (player.balance > 0) {
        cardColor = Colors.cyan.shade100;
      } else if (player.balance == 0) {
        cardColor = Colors.blue.shade100;
      } else {
        cardColor = Colors.purple.shade100;
      }
    } else {
      if (player.balance > 0) {
        cardColor = Colors.green.shade100;
      } else if (player.balance == 0) {
        cardColor = null; // or Colors.white
      } else {
        cardColor = Colors.red.shade100;
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      color: cardColor,
      child: MouseRegion(
        onHover: (PointerHoverEvent event) {
          if (event.synthesized == false && event.buttons == 0) {
            if (HardwareKeyboard.instance.isShiftPressed) {
              // Shift + hover detected
            }
          }
        },
        child: InkWell(
          onTap: () {
            if (HardwareKeyboard.instance.isShiftPressed) {
              print("Shift + Left click!");
            } else if (HardwareKeyboard.instance.isControlPressed) {
              print("Ctrl/Cmd + Left click!");
            } else if (HardwareKeyboard.instance.isAltPressed) {
              print("Alt + Left click!");
            } else {
              onPlayerSelected?.call(player.playerId);
            }
          },
          onDoubleTap: () {
            print("Double-tap!");
          },
          onLongPress: () {
            print("Long press!");
          },
          onSecondaryTap: () {
            print("Right click!");
          },
          child: ListTile(
            title: Text(player.name),
            subtitle: Text('Balance: \$${player.balance.toStringAsFixed(2)}'),
            trailing: player.balance > 0
                ? const Icon(Icons.emergency, color: Colors.green)
                : player.balance < 0
                    ? const Icon(Icons.warning, color: Colors.red)
                    : null,
          ),
        ),
      ),
    );
  }
}