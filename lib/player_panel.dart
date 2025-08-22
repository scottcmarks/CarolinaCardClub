// lib/widgets/player_panel.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// Import your custom files
import '../database_provider.dart'; // Your DatabaseProvider (ChangeNotifier) - Corrected path
import '../models/player_selection_item.dart'; // Your PlayerSelectionItem model

class PlayerPanel extends StatelessWidget {
  final ValueChanged<int?>? onPlayerSelected; // Callback for when a player is tapped
  final int? selectedPlayerId;

  const PlayerPanel({
    super.key,
    this.onPlayerSelected,
    this.selectedPlayerId,
  });

  @override
  Widget build(BuildContext context) {
    // Listen to DatabaseProvider for its loading status and database instance
    return Consumer<DatabaseProvider>(
      builder: (context, databaseProvider, child) {
        // Handle different loading states of the database itself
        switch (databaseProvider.loadStatus) {
          case DatabaseLoadStatus.initial:
          case DatabaseLoadStatus.loadingRemote:
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text('Downloading database...'), // More specific message
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
                  Text('Loading database from assets...'), // Informing about fallback
                ],
              ),
            );
          case DatabaseLoadStatus.error:
            // The database itself failed to load
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
            // Database is loaded, now load panel-specific data using a FutureBuilder
            return FutureBuilder<List<PlayerSelectionItem>>(
              future: databaseProvider.fetchPlayerSelectionList(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  // This error is from fetching players, not the database itself loading
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
                      final int playerId = player.playerId;
                      final bool isSelected = playerId == selectedPlayerId;
                      final bool inArrears = player.balance < 0; // Assuming PlayerSelectionItem has balance

                      // Determine background color based on balance
                      Color? cardColor =
                          isSelected
                          ? inArrears
                            ? Colors.purple.shade100
                            : Colors.blue.shade100
                          : inArrears
                            ? Colors.red.shade100
                            : null;

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
                                print("Regular Left click!");
                              }
                              onPlayerSelected?.call(playerId); // Your original logic
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
                            ),
                          ),
                        ),
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
