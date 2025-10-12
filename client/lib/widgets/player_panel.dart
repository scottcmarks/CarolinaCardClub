// client/lib/widgets/player_panel.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/payment.dart';
import '../models/player_selection_item.dart';
import '../models/session.dart';
import '../providers/api_provider.dart';
import '../providers/time_provider.dart';

class PlayerPanel extends StatefulWidget {
  final int? selectedPlayerId;
  final ValueChanged<int?>? onPlayerSelected;
  final ValueChanged<int>? onSessionAdded;
  final DateTime? clubSessionStartDateTime;

  const PlayerPanel({
    super.key,
    this.selectedPlayerId,
    this.onPlayerSelected,
    this.onSessionAdded,
    this.clubSessionStartDateTime,
  });

  @override
  State<PlayerPanel> createState() => PlayerPanelState();
}

class PlayerPanelState extends State<PlayerPanel> {
  // ... _startNewSession and _showAddMoneyDialog remain the same ...
  Future<void> _startNewSession(ApiProvider apiProvider,
      TimeProvider timeProvider, PlayerSelectionItem player) async {
    try {
      final now = timeProvider.currentTime;
      final sessionStart = widget.clubSessionStartDateTime != null &&
              now.isBefore(widget.clubSessionStartDateTime!)
          ? widget.clubSessionStartDateTime!
          : now;

      final newSession = Session(
        playerId: player.playerId,
        startEpoch: sessionStart.millisecondsSinceEpoch ~/ 1000,
      );
      final newSessionId = await apiProvider.addSession(newSession);

      if (!mounted) return;
      widget.onSessionAdded?.call(newSessionId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting session: $e')),
      );
    }
  }

  void _showAddMoneyDialog(
      ApiProvider apiProvider,
      TimeProvider timeProvider,
      PlayerSelectionItem player,
      {required bool startSessionAfter}) {
    final TextEditingController amountController = TextEditingController();
    if (player.balance < 0) {
      amountController.text = (-player.balance).toStringAsFixed(2);
    }

    showDialog(
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
                onPressed: () => Navigator.of(dialogContext).pop()),
            TextButton(
              child: const Text('OK'),
              onPressed: () async {
                final double? amount = double.tryParse(amountController.text);
                if (amount != null && amount > 0) {
                  final navigator = Navigator.of(dialogContext);
                  final scaffoldMessenger = ScaffoldMessenger.of(context);

                  final newPayment = Payment(
                    playerId: player.playerId,
                    amount: amount,
                    epoch:
                        timeProvider.currentTime.millisecondsSinceEpoch ~/ 1000,
                  );

                  try {
                    final updatedPlayer =
                        await apiProvider.addPayment(newPayment.toMap());

                    navigator.pop();
                    if (!mounted) return;

                    _showPlayerMenu(updatedPlayer);

                  } catch (e) {
                    if (!mounted) return;
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


  void _showPlayerMenu(PlayerSelectionItem player) {
    // Get apiProvider outside the builder
    final apiProvider = Provider.of<ApiProvider>(context, listen: false);

    showDialog(
      context: context,
      // **MODIFICATION**: The whole dialog is now wrapped in a Consumer
      // to listen for time updates and recalculate the balance. ✅
      builder: (BuildContext dialogContext) {
        return Consumer<TimeProvider>(
          builder: (context, timeProvider, child) {
            final double dynamicBalance = apiProvider.getDynamicBalance(
              playerId: player.playerId,
              currentTime: timeProvider.currentTime,
              clubSessionStartDateTime: widget.clubSessionStartDateTime,
            );

            final currencyFormatter =
                NumberFormat.currency(symbol: '\$', decimalDigits: 0);
            final formattedBalance = currencyFormatter.format(dynamicBalance);
            final titleText = '${player.name}: balance is $formattedBalance';

            final canStartSession = widget.clubSessionStartDateTime != null;

            if (dynamicBalance < 0) {
              return AlertDialog(
                backgroundColor: Colors.red.shade100,
                title: Text(titleText),
                content: const Text('Please add money to continue.'),
                actions: [
                  TextButton(
                      child: const Text('Cancel'),
                      onPressed: () {
                        widget.onPlayerSelected?.call(null);
                        Navigator.of(dialogContext).pop();
                      }),
                  TextButton(
                      child: const Text('Add Money'),
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        if (!mounted) return;
                        _showAddMoneyDialog(apiProvider, timeProvider, player,
                            startSessionAfter: canStartSession);
                      }),
                ],
              );
            } else {
              return AlertDialog(
                backgroundColor: Colors.green.shade100,
                title: Text(titleText),
                content: player.hasActiveSession
                    ? const Text('This player already has an active session.')
                    : const Text('What would you like to do?'),
                actions: [
                  if (canStartSession && !player.hasActiveSession)
                    TextButton(
                        child: const Text('Open a new session'),
                        onPressed: () async {
                          Navigator.of(dialogContext).pop();
                          if (!mounted) return;
                          await _startNewSession(apiProvider, timeProvider, player);
                        }),
                  TextButton(
                      child: const Text('Add Money'),
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        if (!mounted) return;
                        _showAddMoneyDialog(apiProvider, timeProvider, player,
                            startSessionAfter: false);
                      }),
                ],
              );
            }
          },
        );
      },
    );
  }

  // ... build method and PlayerCard remain the same ...
  @override
  Widget build(BuildContext context) {
    final apiProvider = context.watch<ApiProvider>();
    final players = apiProvider.players;

    if (players.isEmpty) {
      return const Center(child: Text('No players found.'));
    }

    return SingleChildScrollView(
      key: const PageStorageKey<String>('PlayerListScrollPosition'),
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: players.map((player) {
            return PlayerCard(
              player: player,
              isSelected: player.playerId == widget.selectedPlayerId,
              onTap: () {
                if (player.playerId == widget.selectedPlayerId) {
                  widget.onPlayerSelected?.call(null);
                } else {
                  widget.onPlayerSelected?.call(player.playerId);
                  _showPlayerMenu(player);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

class PlayerCard extends StatelessWidget {
  final PlayerSelectionItem player;
  final bool isSelected;
  final VoidCallback onTap;

  const PlayerCard({
    super.key,
    required this.player,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color? cardColor;
    if (player.balance > 0) {
      cardColor = Colors.green.shade100;
    } else if (player.balance < 0) {
      cardColor = Colors.red.shade100;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      color: cardColor,
      shape: isSelected
          ? RoundedRectangleBorder(
              side:
                  BorderSide(color: Theme.of(context).primaryColor, width: 2.0),
              borderRadius: BorderRadius.circular(4.0),
            )
          : null,
      child: InkWell(
        onTap: onTap,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
          title: Text(
            player.name,
            style: Theme.of(context).textTheme.titleLarge,
            softWrap: false,
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}