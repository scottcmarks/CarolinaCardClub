// client/lib/widgets/session_panel.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/api_provider.dart';
import '../models/session_panel_item.dart';
import '../models/session.dart';
import '../models/poker_table.dart';
import 'location_selector_widget.dart';

class SessionPanel extends StatefulWidget {
  const SessionPanel({Key? key}) : super(key: key);

  @override
  State<SessionPanel> createState() => _SessionPanelState();
}

class _SessionPanelState extends State<SessionPanel> {
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
        final sessions = apiProvider.sessions.where((s) => s.stopTime == null).toList();
        final clubStartTime = apiProvider.clubSessionStartDateTime;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- HEADER SECTION ---
            Card(
              margin: const EdgeInsets.all(8.0),
              elevation: 3,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.access_time_filled, color: Colors.blueAccent),
                    const SizedBox(width: 8),
                    Text(
                      clubStartTime != null
                          ? "Club Session Started: ${DateFormat('h:mm a').format(clubStartTime)}"
                          : "No Club Session Active",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

            // --- LIST SECTION ---
            Expanded(
              child: sessions.isEmpty
                  ? const Center(child: Text("No active sessions."))
                  : ListView.builder(
                      itemCount: sessions.length,
                      itemBuilder: (ctx, index) {
                        return _buildSessionCard(context, apiProvider, sessions[index]);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSessionCard(
      BuildContext context, ApiProvider apiProvider, SessionPanelItem session) {

    final effectiveEndTime = session.stopTime ?? DateTime.now();
    final duration = effectiveEndTime.difference(session.startTime);
    final hours = duration.inSeconds / 3600.0;

    double currentCost = session.isPrepaid ? session.prepayAmount : (hours * session.rate);
    final currentBalance = session.balance - currentCost;
    final isVip = session.rate == 0;

    final tableName = apiProvider.pokerTables
        .firstWhere((t) => t.pokerTableId == session.pokerTableId,
            orElse: () => PokerTable(pokerTableId: -1, name: "Unknown", capacity: 0, isActive: false))
        .name;

    final seatDisplay = session.seatNumber != null ? "Seat ${session.seatNumber}" : "Standing";

    String durationText = "${duration.inHours}h ${duration.inMinutes.remainder(60)}m";
    if (duration.inDays > 0) durationText = "${duration.inDays}d ${duration.inHours.remainder(24)}h";

    return Card(
      color: Colors.blue.shade50,
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        title: Text(session.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("$tableName - $seatDisplay"),
            Text("Running ($durationText)"),
            if (!isVip) ...[
               Text("Cost: \$${currentCost.toStringAsFixed(2)}"),
               Text(
                "Bal: \$${currentBalance.toStringAsFixed(2)}",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: currentBalance < 0 ? Colors.red : Colors.black,
                ),
              ),
            ]
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => _showSessionOptions(context, apiProvider, session, tableName),
        ),
      ),
    );
  }

  void _showSessionOptions(
      BuildContext context,
      ApiProvider apiProvider,
      SessionPanelItem session,
      String currentTableName) {

    final isVip = session.rate == 0;

    // Occupancy Map
    final occupancyMap = <int, Map<int, String>>{};
    for (var s in apiProvider.sessions) {
      if (s.stopTime == null && s.pokerTableId != null && s.seatNumber != null) {
        occupancyMap.putIfAbsent(s.pokerTableId!, () => {})[s.seatNumber!] = s.name;
      }
    }

    // --- PONY LOGIC ---
    final bool isPony = session.playerId == 1;
    final bool isPonyActive = apiProvider.sessions.any((s) => s.playerId == 1 && s.stopTime == null);

    Map<int, int>? preferredSeat;
    final table1 = apiProvider.pokerTables.where((t) => t.name == "Table 1").firstOrNull;

    if (table1 != null) {
      if (isPony) {
        preferredSeat = { table1.pokerTableId: 7 };
      } else {
        if (!isPonyActive) {
           final occupiedCount = (occupancyMap[table1.pokerTableId] ?? {}).length;
           if (occupiedCount < (table1.capacity - 1)) {
              occupancyMap.putIfAbsent(table1.pokerTableId, () => {})[7] = "RESERVED";
           }
        }
      }
    }

    final candidateTables = apiProvider.pokerTables.where((t) {
      if (!t.isActive) return false;
      if (t.pokerTableId == session.pokerTableId) return false;
      final occupiedCount = (occupancyMap[t.pokerTableId] ?? {}).length;
      return occupiedCount < t.capacity;
    }).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Manage: ${session.name}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Currently at $currentTableName"),
            const SizedBox(height: 20),

            if (candidateTables.isNotEmpty) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text("Move Table"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade100, foregroundColor: Colors.orange.shade900),
                  onPressed: () {
                      Navigator.pop(ctx);
                      _showMoveDialog(context, apiProvider, session, candidateTables, occupancyMap, preferredSeat);
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],

            if (!isVip) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.attach_money),
                  label: const Text("Add Money"),
                  onPressed: () {
                     Navigator.pop(ctx);
                     _showAddMoneyDialog(context, apiProvider, session);
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],

            const Divider(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text("Stop Session"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade100, foregroundColor: Colors.red.shade900),
                onPressed: () async {
                  // STOP SESSION LOGIC
                  final stopTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
                  final updatedSession = Session(
                    sessionId: session.sessionId,
                    playerId: session.playerId,
                    // Preserve original start time!
                    startEpoch: session.startTime.millisecondsSinceEpoch ~/ 1000,
                    stopEpoch: stopTime,
                    pokerTableId: session.pokerTableId ?? -1,
                    seatNumber: session.seatNumber,
                    isPrepaid: session.isPrepaid,
                    prepayAmount: session.prepayAmount,
                  );

                  try {
                    await apiProvider.updateSession(updatedSession);
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                    }
                  }
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel"))
        ],
      ),
    );
  }

  void _showMoveDialog(
      BuildContext context,
      ApiProvider apiProvider,
      SessionPanelItem session,
      List<PokerTable> candidateTables,
      Map<int, Map<int, String>> occupancyMap,
      Map<int, int>? preferredSeat) {

    int selectedTableId = candidateTables.first.pokerTableId;
    int? selectedSeat;

    if (preferredSeat != null) {
      for (var tId in preferredSeat.keys) {
         if (candidateTables.any((t) => t.pokerTableId == tId)) {
           selectedTableId = tId;
           break;
         }
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Move Table"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   const Text("Select a table and an available seat."),
                   const SizedBox(height: 16),
                   LocationSelectorWidget(
                     tables: candidateTables,
                     occupancyMap: occupancyMap,
                     preferredSeat: preferredSeat,
                     requireSeat: true,
                     onChanged: (tId, sNum) {
                       setState(() {
                         selectedTableId = tId;
                         selectedSeat = sNum;
                       });
                     },
                   )
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: (selectedSeat == null)
                  ? null
                  : () async {
                      // MOVE SESSION LOGIC
                      final updatedSession = Session(
                        sessionId: session.sessionId,
                        playerId: session.playerId,
                        // Preserve Start Time
                        startEpoch: session.startTime.millisecondsSinceEpoch ~/ 1000,
                        stopEpoch: null,
                        pokerTableId: selectedTableId,
                        seatNumber: selectedSeat,
                        isPrepaid: session.isPrepaid,
                        prepayAmount: session.prepayAmount,
                      );

                      try {
                        await apiProvider.updateSession(updatedSession);
                        Navigator.pop(ctx);
                      } catch (e) {
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Move failed: $e"), backgroundColor: Colors.red));
                      }
                    },
                child: const Text("Confirm Move"),
              )
            ],
          );
        }
      ),
    );
  }

  void _showAddMoneyDialog(
      BuildContext context, ApiProvider apiProvider, SessionPanelItem session) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Add Money: ${session.name}"),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: "Amount", prefixText: "\$"),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text) ?? 0.0;
              if (amount != 0) {
                 try {
                   await apiProvider.addPayment({
                    'Player_Id': session.playerId,
                    'Amount': amount,
                    'Epoch': DateTime.now().millisecondsSinceEpoch ~/ 1000
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                 } catch (e) {
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Payment failed: $e"), backgroundColor: Colors.red));
                 }
              }
            },
            child: const Text("Add"),
          )
        ],
      ),
    );
  }
}