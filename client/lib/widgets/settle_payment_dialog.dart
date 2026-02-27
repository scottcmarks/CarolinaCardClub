// client/lib/widgets/settle_payment_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player_selection_item.dart';
import '../providers/api_provider.dart';
import '../providers/time_provider.dart';

class SettlePaymentDialog extends StatefulWidget {
  final PlayerSelectionItem player;

  const SettlePaymentDialog({super.key, required this.player});

  @override
  State<SettlePaymentDialog> createState() => _SettlePaymentDialogState();
}

class _SettlePaymentDialogState extends State<SettlePaymentDialog> {
  final TextEditingController _amountController = TextEditingController();
  bool _initialized = false;
  int _currentBalance = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initialized) {
      final api = Provider.of<ApiProvider>(context, listen: false);
      final timeProvider = Provider.of<TimeProvider>(context, listen: false);

      _currentBalance = api.getDynamicBalance(widget.player, timeProvider.nowEpoch);

      // Auto-fill the amount needed to zero out the account
      if (_currentBalance != 0) {
        _amountController.text = (_currentBalance * -1).toString();
      }

      _initialized = true;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = Provider.of<ApiProvider>(context, listen: false);
    final timeProvider = Provider.of<TimeProvider>(context, listen: false);

    return AlertDialog(
      title: Text("Settle: ${widget.player.name}"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Current Balance: \$$_currentBalance",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _currentBalance < 0 ? Colors.red : Colors.green,
            )
          ),
          const SizedBox(height: 16),
          const Text(
            "Positive amounts add to the player's balance (e.g., paying off debt).\nNegative amounts subtract from the balance (e.g., cashing out winnings).",
            style: TextStyle(fontSize: 12, color: Colors.grey)
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _amountController,
            decoration: const InputDecoration(
              labelText: "Amount (Dollars)",
              prefixIcon: Icon(Icons.attach_money),
            ),
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel")
        ),
        ElevatedButton(
          onPressed: () async {
            final amount = int.tryParse(_amountController.text);
            if (amount != null && amount != 0) {
              final epoch = timeProvider.nowEpoch;
              try {
                await api.addPayment(widget.player.playerId, amount, epoch);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Payment of \$$amount applied to ${widget.player.name}."))
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Payment Error: $e"))
                  );
                }
              }
            }
          },
          child: const Text("Apply Payment"),
        ),
      ],
    );
  }
}