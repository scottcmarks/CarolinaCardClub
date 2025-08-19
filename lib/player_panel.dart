// lib/widgets/player_panel.dart
import 'package:flutter/material.dart';
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
                  itemCount: players.length,
                  itemBuilder: (context, index) {
                    final player = players[index];
                    final bool isSelected = player.playerId == selectedPlayerId;
                    return ListTile(
                      leading: const Icon(Icons.person), // Placeholder icon
                      title: Text(player.name),
                      subtitle: Text('Balance: \$${player.balance.toStringAsFixed(2)}'), // Display balance with 2 decimal places
                      selected: isSelected,
                      selectedTileColor: Theme.of(context).colorScheme.primary.withOpacity(0.2), // Light highlight
                      // You can also customize icon/text color when selected
                      // selectedColor: Theme.of(context).colorScheme.onPrimary, // For text/icon color
                                            onTap: () {
                        final int? newSelection = isSelected ? null : player.playerId;
                        // Invoke the callback, passing the playerId of the tapped player
                        onPlayerSelected?.call(newSelection);
                      },
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
