// client/lib/screens/player_selection_panel.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/api_provider.dart';
import '../models/player_selection_item.dart';
import '../models/session.dart';
import '../models/poker_table.dart';

class PlayerSelectionPanel extends StatefulWidget {
  const PlayerSelectionPanel({super.key});

  @override
  State<PlayerSelectionPanel> createState() => _PlayerSelectionPanelState();
}

class _PlayerSelectionPanelState extends State<PlayerSelectionPanel> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ApiProvider>(
      builder: (context, apiProvider, child) {
        final players = apiProvider.players;

        if (players.isEmpty) {
          return const Center(child: Text("No players found."));
        }

        return ListView.builder(
          itemCount: players.length,
          itemBuilder: (ctx, index) {
            final player = players[index];

            final int displayBalance = apiProvider.getDynamicBalance(player);
            final balanceColor = displayBalance < 0 ? Colors.red.shade700 : Colors.grey.shade700;

            return Card(
              color: player.isActive ? Colors.green.shade50 : Colors.white,
              child: ListTile(
                title: Text(player.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  "Balance: \$$displayBalance",
                  style: TextStyle(color: balanceColor, fontWeight: FontWeight.bold),
                ),
                trailing: player.isActive
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.play_circle_outline),
                onTap: () => _handlePlayerTap(context, apiProvider, player),
              ),
            );
          },
        );
      },
    );
  }

  void _handlePlayerTap(BuildContext context, ApiProvider apiProvider, PlayerSelectionItem player) {
    if (player.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Player already active.")));
      return;
    }

    final activeTables = apiProvider.pokerTables.where((t) => t.isActive).toList();

    if (activeTables.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No active tables available.")));
      return;
    }

    final double hourlyRate = player.hourlyRate;
    final int prepayHours = player.prepayHours;
    final double prepayCost = hourlyRate * prepayHours;

    final bool isVip = hourlyRate == 0;
    final bool canNormallyStart = player.balance >= 0;

    final bool offerPrepayOption = !isVip && canNormallyStart && prepayCost > 0;
    final bool showAddMoneyFlow = !isVip && !canNormallyStart;

    final occupancyMap = <int, Map<int, String>>{};
    for (var s in apiProvider.sessions) {
      if (s.pokerTableId != null && s.seatNumber != null) {
        occupancyMap.putIfAbsent(s.pokerTableId!, () => {})[s.seatNumber!] = "Occupied";
      }
    }

    if (showAddMoneyFlow) {
      _showMandatoryPaymentDialog(context, apiProvider, player);
    } else {
      showDialog(
        context: context,
        builder: (ctx) => _StartSessionDialog(
          player: player,
          tables: activeTables,
          occupancyMap: occupancyMap,
          canPrepay: offerPrepayOption,
          isVip: isVip,
          prepayCost: prepayCost,
          prepayHours: prepayHours,
          onStart: (tableId, seatNum, isPrepaid) async {
             await apiProvider.addSession(Session(
              sessionId: 0,
              playerId: player.playerId,
              startEpoch: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              pokerTableId: tableId,
              seatNumber: seatNum,
              isPrepaid: isPrepaid,
              prepayAmount: isPrepaid ? prepayCost : 0.0,
            ));
            if (ctx.mounted) Navigator.pop(ctx);
          },
          onAddPayment: (amount) async {
             await apiProvider.addPayment(
               playerId: player.playerId,
               amount: amount,
             );
          }
        ),
      );
    }
  }

  void _showMandatoryPaymentDialog(BuildContext context, ApiProvider apiProvider, PlayerSelectionItem player) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Negative Balance"),
        content: Text("${player.name} owes \$${-player.balance}.\nMust clear balance to start."),
        actions: [
           TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
           ElevatedButton(
            child: const Text("Clear Debt"),
            onPressed: () async {
               await apiProvider.addPayment(
                 playerId: player.playerId,
                 amount: (-player.balance).toDouble(),
               );
              if (ctx.mounted) Navigator.pop(ctx);
            },
          )
        ],
      ),
    );
  }
}

class _StartSessionDialog extends StatefulWidget {
  final PlayerSelectionItem player;
  final List<PokerTable> tables;
  final Map<int, Map<int, String>> occupancyMap;
  final bool canPrepay;
  final bool isVip;
  final double prepayCost;
  final int prepayHours;
  final Function(int tableId, int? seatNum, bool isPrepaid) onStart;
  final Function(double amount) onAddPayment;

  const _StartSessionDialog({
    required this.player,
    required this.tables,
    required this.occupancyMap,
    required this.canPrepay,
    required this.isVip,
    required this.prepayCost,
    required this.prepayHours,
    required this.onStart,
    required this.onAddPayment,
  });

  @override
  State<_StartSessionDialog> createState() => _StartSessionDialogState();
}

class _StartSessionDialogState extends State<_StartSessionDialog> {
  int? _selectedTableId;
  int? _selectedSeatNumber;
  bool _isPrepaid = false;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Seat ${widget.player.name}"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<int?>(
            decoration: const InputDecoration(labelText: "Select Table"),
            initialValue: _selectedTableId,
            items: [
              const DropdownMenuItem(value: null, child: Text("Unseated (Lobby)")),
              ...widget.tables.map((t) => DropdownMenuItem(
                value: t.pokerTableId,
                child: Text(t.name)
              )),
            ],
            onChanged: _isSubmitting ? null : (val) {
              setState(() {
                _selectedTableId = val;
                _selectedSeatNumber = null;
              });
            },
          ),
          if (widget.canPrepay) ...[
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text("Prepay Session"),
              subtitle: Text(
                _isPrepaid
                  ? "\$${widget.prepayCost.round()} upfront for ${widget.prepayHours} hours"
                  : "Standard Hourly Billing"
              ),
              value: _isPrepaid,
              onChanged: _isSubmitting ? null : (val) => setState(() => _isPrepaid = val),
            ),
          ]
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text("Cancel")
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : () async {
            setState(() => _isSubmitting = true);
            await widget.onStart(_selectedTableId ?? 0, _selectedSeatNumber, _isPrepaid);
            if (mounted) setState(() => _isSubmitting = false);
          },
          child: _isSubmitting
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text("Confirm Seat"),
        ),
      ],
    );
  }
}