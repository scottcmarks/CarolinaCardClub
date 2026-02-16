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
        // FILTER: Only show Active Sessions (Stop_Epoch is NULL)
        // If you want to see history, we should add a toggle, but for Floor Management
        // we usually only want open sessions.
        final sessions = apiProvider.sessions.where((s) => s.stopTime == null).toList();

        final tables = apiProvider.pokerTables;
        final clubStartTime = apiProvider.clubSessionStartDateTime;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- HEADER SECTION ---
            Container(
              padding: const EdgeInsets.all(12.0),
              color: Colors.grey.shade200,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Club Session Info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Club Session:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      if (clubStartTime != null)
                        Text(
                          "Started: ${DateFormat('MMM d, h:mm a').format(clubStartTime)}",
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
                        )
                      else
                        const Text("Not Started", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                    ],
                  ),

                  const SizedBox(height: 8),
                  const Divider(height: 1, color: Colors.white),
                  const SizedBox(height: 8),

                  // 2. Table Availability
                  const Text("Table Availability:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  Wrap(
                    spacing: 12.0,
                    children: tables.map((t) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: t.isActive,
                              onChanged: (val) {
                                apiProvider.toggleTableStatus(t.pokerTableId, val ?? false);
                              },
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(t.name),
                        ],
                      );
                    }).toList(),
                  )
                ],
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

    // *** FIX: Logic to handle Closed vs Open Sessions correctly ***
    final effectiveEndTime = session.stopTime ?? DateTime.now();
    final duration = effectiveEndTime.difference(session.startTime);
    final hours = duration.inSeconds / 3600.0;

    double currentCost = session.isPrepaid ? session.prepayAmount : (hours * session.rate);
    final currentBalance = session.balance - currentCost;
    final isVip = session.rate == 0;
    final isClosed = session.stopTime != null;

    final tableName = apiProvider.pokerTables
        .firstWhere((t) => t.pokerTableId == session.pokerTableId,
            orElse: () => PokerTable(pokerTableId: -1, name: "Unknown", capacity: 0))
        .name;

    final seatDisplay = session.seatNumber != null ? "Seat ${session.seatNumber}" : "Standing";

    // Formatting Duration
    String durationText = "${duration.inHours}h ${duration.inMinutes.remainder(60)}m";
    if (duration.inDays > 0) {
      durationText = "${duration.inDays}d ${duration.inHours.remainder(24)}h";
    }

    return Card(
      color: isClosed ? Colors.grey.shade300 : Colors.blue.shade50, // Gray out if closed
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        title: Text(session.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.table_restaurant, size: 16, color: Colors.grey.shade700),
                const SizedBox(width: 4),
                Text("$tableName - $seatDisplay", style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey.shade700),
                const SizedBox(width: 4),
                Text(isClosed ? "Ended ($durationText)" : "Running ($durationText)"),
              ],
            ),
            if (!isVip) ...[
               const SizedBox(height: 4),
               Text("Cost: \$${currentCost.toStringAsFixed(2)}", style: TextStyle(color: Colors.grey.shade800)),
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
        isThreeLine: true,
        trailing: isClosed
            ? const Chip(label: Text("Closed"))
            : IconButton(
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
    final occupancyMap = <int, List<int>>{};
    for (var s in apiProvider.sessions) {
      if (s.pokerTableId != null && s.seatNumber != null && s.stopTime == null) { // Only count active sessions
        occupancyMap.putIfAbsent(s.pokerTableId!, () => []).add(s.seatNumber!);
      }
    }

    final candidateTables = apiProvider.pokerTables.where((t) {
      if (!t.isActive) return false;
      if (t.pokerTableId == session.pokerTableId) return false;
      final occupiedCount = (occupancyMap[t.pokerTableId] ?? []).length;
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
                      _showMoveDialog(context, apiProvider, session, candidateTables, occupancyMap);
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
                  final stopTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
                  final updatedSession = Session(
                    sessionId: session.sessionId,
                    playerId: session.playerId,
                    stopEpoch: stopTime,
                    pokerTableId: session.pokerTableId ?? -1,
                    seatNumber: session.seatNumber,
                    isPrepaid: session.isPrepaid,
                    prepayAmount: session.prepayAmount,
                  );
                  await apiProvider.updateSession(updatedSession);
                  if (ctx.mounted) Navigator.pop(ctx);
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
      Map<int, List<int>> occupancyMap) {

    int selectedTableId = candidateTables.first.pokerTableId;
    int? selectedSeat;

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
                  : () {
                      _executeMove(context, apiProvider, session, selectedTableId, selectedSeat!);
                      Navigator.pop(ctx);
                    },
                child: const Text("Confirm Move"),
              )
            ],
          );
        }
      ),
    );
  }

  void _executeMove(
      BuildContext context,
      ApiProvider apiProvider,
      SessionPanelItem session,
      int newTableId,
      int newSeatNumber) async {

    final updatedSession = Session(
      sessionId: session.sessionId,
      playerId: session.playerId,
      startEpoch: session.startTime.millisecondsSinceEpoch ~/ 1000,
      stopEpoch: null,
      pokerTableId: newTableId,
      seatNumber: newSeatNumber,
      isPrepaid: session.isPrepaid,
      prepayAmount: session.prepayAmount,
    );

    try {
      await apiProvider.updateSession(updatedSession);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Moved successfully!")));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Move failed: $e"), backgroundColor: Colors.red));
      }
    }
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
                 await apiProvider.addPayment({
                  'Player_Id': session.playerId,
                  'Amount': amount,
                  'Epoch': DateTime.now().millisecondsSinceEpoch ~/ 1000
                });
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text("Add"),
          )
        ],
      ),
    );
  }
}