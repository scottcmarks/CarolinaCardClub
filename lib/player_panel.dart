// lib/widgets/player_panel.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// Import your custom files
import 'database/database_provider.dart'; // Your DatabaseProvider (ChangeNotifier)
import 'models/player_selection_item.dart'; // Your PlayerSelectionItem model

class PlayerPanel extends StatelessWidget {
  final ValueChanged<int?>? onPlayerSelected; // Callback for when a player is tapped
  final int? selectedPlayerId;

  const PlayerPanel({
    super.key,
    this.onPlayerSelected,
    this.selectedPlayerId,
  });

  // Method to fetch player data from the DatabaseProvider
  Future<List<PlayerSelectionItem>> _fetchPlayers(BuildContext context) async {
    final databaseProvider = Provider.of<DatabaseProvider>(context, listen: false);
    // Assuming DatabaseProvider has a method to fetch player list
    List<PlayerSelectionItem> playerList = await databaseProvider.fetchPlayerSelectionList();
    return playerList;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // const Padding(
        //   padding: EdgeInsets.all(16.0),
        //   child: Text(
        //     'Select Player',
        //     style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        //   ),
        // ),
        // const Divider(),
        Expanded(
          child: FutureBuilder<List<PlayerSelectionItem>>(
            future: _fetchPlayers(context),
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
                    final int playerId = player.playerId;
                    final bool isSelected = playerId == selectedPlayerId;
                    final bool inArrears = player.balance < 0;
                    // Determine background color based on balance
                    Color? cardColor =
                      isSelected
                      ? inArrears
                        ? Colors.purple.shade100
                        : Colors.blue.shade100
                      : inArrears
                        ? Colors.red.shade100
                        : null
                    ;
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
                            onPlayerSelected?.call(playerId); // Your original logic for player selection
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
                      )
                    );
                  },
                );
              }
            },
          ),
        ),
      ],
    );
  }
}
