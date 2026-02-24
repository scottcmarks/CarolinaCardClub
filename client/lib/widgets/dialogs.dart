// client/lib/widgets/dialogs.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/player_selection_item.dart';
import '../providers/api_provider.dart';

/// Shows a dialog to add money for a player and returns the updated player on success.
Future<PlayerSelectionItem?> showAddMoneyDialog(
  BuildContext context, {
  required PlayerSelectionItem player,
}) async {
  final apiProvider = Provider.of<ApiProvider>(context, listen: false);
  final TextEditingController amountController = TextEditingController();

  if (player.balance < 0) {
    amountController.text = (-player.balance).toStringAsFixed(2);
  }

  return showDialog<PlayerSelectionItem>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: Text('Add Money for ${player.name}'),
        content: TextField(
          controller: amountController,
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
            onPressed: () => Navigator.of(dialogContext).pop(null),
          ),
          TextButton(
            child: const Text('OK'),
            onPressed: () async {
              final double? amount = double.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                final navigator = Navigator.of(dialogContext);
                final scaffoldMessenger = ScaffoldMessenger.of(dialogContext);

                try {
                  // Use the new named parameters
                  await apiProvider.addPayment(
                    playerId: player.playerId,
                    amount: amount,
                  );

                  if (!dialogContext.mounted) return;

                  // Since addPayment returns void, fetch the updated player to return
                  final updatedPlayer = apiProvider.players.firstWhere(
                    (p) => p.playerId == player.playerId,
                    orElse: () => player,
                  );
                  navigator.pop(updatedPlayer);

                } catch (e) {
                  if (!dialogContext.mounted) return;
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Failed to add payment: $e')),
                  );
                }
              }
            },
          ),
        ],
      );
    },
  );
}