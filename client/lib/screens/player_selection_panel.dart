// lib/screens/player_selection_panel.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/api_provider.dart';
import '../providers/time_provider.dart'; // NEW: Imported TimeProvider
import '../models/player_selection_item.dart';

class PlayerSelectionPanel extends StatelessWidget {
  const PlayerSelectionPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final api = Provider.of<ApiProvider>(context);
    final timeProvider = Provider.of<TimeProvider>(context); // NEW: Inject TimeProvider
    final players = api.players;

    return ListView.builder(
      itemCount: players.length,
      itemBuilder: (context, index) {
        final player = players[index];
        // FIXED: Added timeProvider.nowEpoch to calculate balance based on simulated time
        final int currentBalance = api.getDynamicBalance(player, timeProvider.nowEpoch);

        return ListTile(
          title: Text(player.name),
          subtitle: Text("Balance: \$$currentBalance"),
          onTap: () => _showPaymentDialog(context, api, player),
        );
      },
    );
  }

  void _showPaymentDialog(BuildContext context, ApiProvider api, PlayerSelectionItem player) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Add Payment for ${player.name}"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Amount (Whole Dollars)"),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text)?.round() ?? 0;
              if (amount > 0) {
                // NEW: Grab the time context right before executing the network request
                final timeProvider = Provider.of<TimeProvider>(context, listen: false);

                // FIXED: Positional arguments now include the simulated epoch
                await api.addPayment(player.playerId, amount, timeProvider.nowEpoch);

                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }
}