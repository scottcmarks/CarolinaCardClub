// client/lib/pages/tablet_table_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/api_provider.dart';
import '../providers/time_provider.dart';
import '../models/poker_table.dart';
import '../models/session.dart';
import '../models/player_selection_item.dart';
import '../widgets/location_selector_widget.dart';
import '../widgets/real_time_clock.dart';
import 'table_view_page.dart';

class TabletTablePage extends StatelessWidget {
  final PokerTable table;

  const TabletTablePage({super.key, required this.table});

  @override
  Widget build(BuildContext context) {
    final api = Provider.of<ApiProvider>(context);
    final time = Provider.of<TimeProvider>(context);

    final occupancy = <int, String>{};
    for (var s in api.sessions.where(
        (s) => s.stopTime == null && s.pokerTableId == table.pokerTableId)) {
      if (s.seatNumber != null) occupancy[s.seatNumber!] = s.name;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(table.tableName),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.blue.shade900),
                const SizedBox(width: 8),
                const RealTimeClock(),
              ],
            ),
          ),
        ],
      ),
      body: LocationSelectorWidget(
        table: table,
        occupancy: occupancy,
        onSeatSelected: (_) {}, // unused in tablet mode
        isSubPageMode: false,
        onStandUp: (session) => _confirmStandUp(context, session, time),
        onMarkAway: (session) => _confirmMarkAway(context, session, time),
        onMarkReturn: (session) => _markReturn(context, session),
        onMoveSeat: (session) => _showMoveSeat(context, session, api, time),
        onSeatPlayer: (seatNum) => _showSeatPlayer(context, seatNum, api, time),
      ),
    );
  }

  // --- Stand Up ---

  void _confirmStandUp(BuildContext context, Session session, TimeProvider time) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Stand Up: ${session.name}?"),
        content: const Text("This will end the session and update the player's balance."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final api = Provider.of<ApiProvider>(context, listen: false);
              try {
                await api.stopSession(session.sessionId, time.nowEpoch);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text("Stand Up"),
          ),
        ],
      ),
    );
  }

  // --- Mark Away ---

  void _confirmMarkAway(BuildContext context, Session session, TimeProvider time) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Mark Away: ${session.name}?"),
        content: const Text("Player's session will continue running while away."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final api = Provider.of<ApiProvider>(context, listen: false);
              try {
                await api.markAway(session.sessionId, time.nowEpoch);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text("Mark Away"),
          ),
        ],
      ),
    );
  }

  // --- Mark Return ---

  void _markReturn(BuildContext context, Session session) async {
    final api = Provider.of<ApiProvider>(context, listen: false);
    try {
      await api.markReturn(session.sessionId);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- Move Seat (within same table) ---

  void _showMoveSeat(BuildContext context, Session session, ApiProvider api, TimeProvider time) {
    // Use existing TableViewPage in sub-page mode to pick a new seat
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TableViewPage(
          table: table,
          pendingPlayerId: session.playerId,
          highlightedSeat: session.seatNumber,
        ),
      ),
    ).then((newSeat) async {
      if (newSeat == null || newSeat == session.seatNumber) return;
      try {
        await api.moveSession(session.sessionId, table.pokerTableId, newSeat, time.nowEpoch);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
          );
        }
      }
    });
  }

  // --- Seat a Player ---

  void _showSeatPlayer(BuildContext context, int seatNum, ApiProvider api, TimeProvider time) {
    // Filter to players with no open session and balance >= 0
    final eligible = api.players.where((p) {
      if (p.isActive) return false;
      final balance = api.getDynamicBalance(p, time.nowEpoch);
      return balance >= 0;
    }).toList();

    if (eligible.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("No Eligible Players"),
          content: const Text("All players either have an active session or a negative balance."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK")),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => _SeatPlayerDialog(
        table: table,
        seatNum: seatNum,
        eligible: eligible,
        api: api,
        time: time,
      ),
    );
  }
}

// --- Seat Player Dialog ---

class _SeatPlayerDialog extends StatefulWidget {
  final PokerTable table;
  final int seatNum;
  final List<PlayerSelectionItem> eligible;
  final ApiProvider api;
  final TimeProvider time;

  const _SeatPlayerDialog({
    required this.table,
    required this.seatNum,
    required this.eligible,
    required this.api,
    required this.time,
  });

  @override
  State<_SeatPlayerDialog> createState() => _SeatPlayerDialogState();
}

class _SeatPlayerDialogState extends State<_SeatPlayerDialog> {
  PlayerSelectionItem? _selected;
  bool _isPrepaid = false;

  int get _balance => _selected == null
      ? 0
      : widget.api.getDynamicBalance(_selected!, widget.time.nowEpoch);

  int get _targetPrepay => _selected == null
      ? 0
      : (_selected!.prepayHours * _selected!.hourlyRate).round();

  bool get _canPrepay => _selected != null && _balance >= _targetPrepay && _targetPrepay > 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Seat at ${widget.table.tableName} — Seat ${widget.seatNum}"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<PlayerSelectionItem>(
              decoration: const InputDecoration(labelText: "Select Player"),
              initialValue: _selected,
              items: widget.eligible.map((p) {
                final bal = widget.api.getDynamicBalance(p, widget.time.nowEpoch);
                return DropdownMenuItem(
                  value: p,
                  child: Text("${p.name}  (\$$bal)"),
                );
              }).toList(),
              onChanged: (val) => setState(() {
                _selected = val;
                _isPrepaid = false;
              }),
            ),

            if (_selected != null && _canPrepay) ...[
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text("Prepaid Session"),
                subtitle: Text("Cost: \$$_targetPrepay (balance covers it)"),
                value: _isPrepaid,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) => setState(() => _isPrepaid = val),
              ),
            ],

            if (_selected != null && !_canPrepay && _targetPrepay > 0) ...[
              const SizedBox(height: 12),
              Text(
                "Prepay not available — balance \$$_balance < required \$$_targetPrepay",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: _selected == null ? null : () async {
            Navigator.pop(context);
            final player = _selected!;
            final nowEpoch = widget.time.nowEpoch;

            try {
              await widget.api.addSession(
                Session(
                  sessionId: 0,
                  playerId: player.playerId,
                  name: player.name,
                  pokerTableId: widget.table.pokerTableId,
                  seatNumber: widget.seatNum,
                  startEpoch: nowEpoch,
                  isPrepaid: _isPrepaid,
                  prepayAmount: _isPrepaid ? _targetPrepay : 0,
                  hourlyRate: player.hourlyRate,
                ),
                nowEpoch,
              );
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                );
              }
            }
          },
          child: const Text("Seat Player"),
        ),
      ],
    );
  }
}
