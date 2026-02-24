// lib/screens/player_selection_panel.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/api_provider.dart';
import '../models/player_selection_item.dart';

class PlayerSelectionPanel extends StatelessWidget {
  const PlayerSelectionPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final api = Provider.of<ApiProvider>(context);
    final players = api.players;

    return ListView.builder(
      itemCount: players.length,
      itemBuilder: (context, index) {
        final player = players[index];
        // Ensure the dynamic balance (int) is treated correctly
        final int currentBalance = api.getDynamicBalance(player);

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
              // FIX: Convert input to int and use positional arguments
              final amount = double.tryParse(controller.text)?.round() ?? 0;
              if (amount > 0) {
                // FIXED: Positional arguments (playerId, amount)
                await api.addPayment(player.playerId, amount);
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