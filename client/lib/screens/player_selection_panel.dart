// client/lib/screens/player_selection_panel.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/api_provider.dart';
import '../models/player_selection_item.dart';
import '../models/session.dart';
import '../models/poker_table.dart';
import '../widgets/location_selector_widget.dart';

class PlayerSelectionPanel extends StatefulWidget {
  const PlayerSelectionPanel({Key? key}) : super(key: key);

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
            final displayBalance = apiProvider.getDynamicBalance(
              playerId: player.playerId,
              currentTime: DateTime.now(),
            );
            final balanceColor = displayBalance < 0 ? Colors.red.shade700 : Colors.grey.shade700;

            return Card(
              color: player.isActive ? Colors.green.shade50 : Colors.white,
              child: ListTile(
                title: Text(player.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  "Balance: \$${displayBalance.toStringAsFixed(2)}",
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

    // Filter active tables only
    final activeTables = apiProvider.pokerTables.where((t) => t.isActive).toList();

    if (activeTables.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No active tables available.")));
      return;
    }

    // --- LOGIC ---
    final double hourlyRate = player.hourlyRate;
    final int prepayHours = player.prepayHours;
    final double prepayCost = hourlyRate * prepayHours;

    final bool isVip = hourlyRate == 0;

    final bool canNormallyStart = player.balance >= -0.01;

    final bool offerPrepayOption = !isVip && canNormallyStart && prepayCost > 0;
    final bool showAddMoneyFlow = !isVip && !canNormallyStart;

    // Build Occupancy Map for Start Dialog
    final occupancyMap = <int, List<int>>{};
    for (var s in apiProvider.sessions) {
      if (s.pokerTableId != null && s.seatNumber != null) {
        occupancyMap.putIfAbsent(s.pokerTableId!, () => []).add(s.seatNumber!);
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
              playerId: player.playerId,
              startEpoch: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              pokerTableId: tableId,
              seatNumber: seatNum,
              isPrepaid: isPrepaid,
              prepayAmount: isPrepaid ? prepayCost : 0.0,
            ));
            if (context.mounted) Navigator.pop(ctx);
          },
          onAddPayment: (amount) async {
             await apiProvider.addPayment({
              'Player_Id': player.playerId,
              'Amount': amount,
              'Epoch': DateTime.now().millisecondsSinceEpoch ~/ 1000
            });
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
        content: Text("${player.name} owes \$${(-player.balance).toStringAsFixed(2)}.\nMust clear balance to start."),
        actions: [
           TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
           ElevatedButton(
            child: const Text("Clear Debt"),
            onPressed: () async {
               await apiProvider.addPayment({
                'Player_Id': player.playerId,
                'Amount': -player.balance,
                'Epoch': DateTime.now().millisecondsSinceEpoch ~/ 1000
              });
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
  final Map<int, List<int>> occupancyMap;
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
  late int _selectedTableId;
  int? _selectedSeat;
  bool _isPrepaid = false;

  @override
  void initState() {
    super.initState();
    // Default to first non-full table
    _selectedTableId = widget.tables.first.pokerTableId;
    for(var t in widget.tables) {
      final occupied = widget.occupancyMap[t.pokerTableId] ?? [];
      if (occupied.length < t.capacity) {
        _selectedTableId = t.pokerTableId;
        break;
      }
    }

    if (widget.isVip) _isPrepaid = true;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Start: ${widget.player.name}"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.isVip)
              Text("Current Balance: \$${widget.player.balance.toStringAsFixed(2)}"),

            const SizedBox(height: 16),
            LocationSelectorWidget(
              tables: widget.tables,
              occupancyMap: widget.occupancyMap,
              onChanged: (tableId, seatNum) {
                setState(() {
                  _selectedTableId = tableId;
                  _selectedSeat = seatNum;
                });
              },
            ),
            const SizedBox(height: 16),
            const Divider(),

            if (widget.isVip) ...[
               const ListTile(
                 leading: Icon(Icons.star, color: Colors.amber),
                 title: Text("VIP Session"),
                 subtitle: Text("No hourly charge."),
               )
            ] else if (widget.canPrepay) ...[
              CheckboxListTile(
                title: const Text("Prepay Session?"),
                subtitle: Text("${widget.prepayHours} hrs for \$${widget.prepayCost.toStringAsFixed(2)}"),
                value: _isPrepaid,
                onChanged: (val) {
                  setState(() => _isPrepaid = val ?? false);
                  if (_isPrepaid) _checkPrepayFunds();
                },
              ),
            ]
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: () => widget.onStart(_selectedTableId, _selectedSeat, _isPrepaid),
          child: const Text("Start Session"),
        ),
      ],
    );
  }

  void _checkPrepayFunds() {
    final deficit = widget.prepayCost - widget.player.balance;
    if (deficit > 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Add Funds"),
          content: Text("Add \$${deficit.toStringAsFixed(2)} for prepay?"),
          actions: [
            TextButton(
              child: const Text("No"),
              onPressed: () {
                setState(() => _isPrepaid = false);
                Navigator.pop(ctx);
              },
            ),
            ElevatedButton(
              child: const Text("Add & Continue"),
              onPressed: () async {
                await widget.onAddPayment(deficit);
                if (mounted) Navigator.pop(ctx);
              },
            )
          ],
        ),
      );
    }
  }
}