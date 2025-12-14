// client/lib/widgets/dialogs.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/payment.dart';
import '../models/player_selection_item.dart';
import '../providers/api_provider.dart';
import '../providers/time_provider.dart';

/// Shows a dialog to add money for a player and returns the updated player on success.
Future<PlayerSelectionItem?> showAddMoneyDialog(
  BuildContext context, {
  required PlayerSelectionItem player,
}) async {
  final apiProvider = Provider.of<ApiProvider>(context, listen: false);
  final timeProvider = Provider.of<TimeProvider>(context, listen: false);
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
            onPressed: () =>
                Navigator.of(dialogContext).pop(null), // Return null on cancel
          ),
          TextButton(
            child: const Text('OK'),
            onPressed: () async {
              final double? amount = double.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                // *** FIX 1: Use dialogContext for BOTH Navigator and ScaffoldMessenger ***
                final navigator = Navigator.of(dialogContext);
                final scaffoldMessenger = ScaffoldMessenger.of(dialogContext);

                final newPayment = Payment(
                  playerId: player.playerId,
                  amount: amount,
                  epoch:
                      timeProvider.currentTime.millisecondsSinceEpoch ~/ 1000,
                );

                try {
                  final updatedPlayer =
                      await apiProvider.addPayment(newPayment.toMap());
                  // Return the updated player object on success
                  navigator.pop(updatedPlayer);
                } catch (e) {
                  // *** FIX 2: Check dialogContext is still mounted AFTER the await ***
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
