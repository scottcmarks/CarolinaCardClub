// client/lib/widgets/table_closing_wizard.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/session.dart';
import '../models/poker_table.dart';
import '../providers/api_provider.dart';
import '../providers/time_provider.dart';
import 'seat_selector_widget.dart';

class TableClosingWizard extends StatefulWidget {
  final PokerTable closingTable;
  final List<Session> strandedSessions;

  const TableClosingWizard({
    super.key,
    required this.closingTable,
    required this.strandedSessions,
  });

  @override
  State<TableClosingWizard> createState() => _TableClosingWizardState();
}

class _TableClosingWizardState extends State<TableClosingWizard> {
  int _currentIndex = 0;
  int? _selectedTableId;
  int? _selectedSeat;

  bool get _isValidMove => _selectedTableId != null && _selectedSeat != null;

  Future<void> _advanceOrFinish() async {
    final api = Provider.of<ApiProvider>(context, listen: false);

    if (_currentIndex < widget.strandedSessions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedTableId = null;
        _selectedSeat = null;
      });
    } else {
      // List exhausted. Safe to toggle the table off.
      await api.toggleTableStatus(widget.closingTable.pokerTableId, false);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${widget.closingTable.tableName} closed successfully."))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = Provider.of<ApiProvider>(context);
    final timeProvider = Provider.of<TimeProvider>(context, listen: false);

    final currentSession = widget.strandedSessions[_currentIndex];

    // Filter out the table we are currently trying to close!
    final availableTables = api.activeTables
        .where((t) => t.pokerTableId != widget.closingTable.pokerTableId)
        .toList();

    return AlertDialog(
      title: Text("Closing ${widget.closingTable.tableName}"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Player ${_currentIndex + 1} of ${widget.strandedSessions.length}:",
                style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(currentSession.name, style: const TextStyle(fontSize: 22, color: Colors.blue)),
            const SizedBox(height: 16),

            if (availableTables.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.red.shade50,
                child: const Text(
                  "No other active tables available. You must stop this session to proceed.",
                  style: TextStyle(color: Colors.red)
                ),
              )
            else ...[
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: "Move to Table"),
                initialValue: _selectedTableId,
                items: availableTables.map((t) => DropdownMenuItem(
                  value: t.pokerTableId,
                  child: Text(t.tableName),
                )).toList(),
                onChanged: (val) => setState(() {
                  _selectedTableId = val;
                  _selectedSeat = null;
                }),
              ),
              const SizedBox(height: 16),
              if (_selectedTableId != null)
                SeatSelectorWidget(
                  initialSeat: _selectedSeat,
                  maxSeats: api.tables.firstWhere((t) => t.pokerTableId == _selectedTableId).capacity,
                  // FIXED: Added tableName
                  tableName: api.tables.firstWhere((t) => t.pokerTableId == _selectedTableId).tableName,
                  // FIXED: Switched to the new Map-based function
                  occupiedSeats: api.getOccupiedSeatsAndNamesForTable(_selectedTableId!),
                  onSeatSelected: (seat) => setState(() => _selectedSeat = seat),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel Wizard")
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade50,
            foregroundColor: Colors.red.shade900
          ),
          onPressed: () async {
            try {
              final stopEpoch = timeProvider.nowEpoch;
              await api.stopSession(currentSession.sessionId, stopEpoch);
              await _advanceOrFinish();
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
              }
            }
          },
          child: const Text("Stop Session"),
        ),
        if (availableTables.isNotEmpty)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white
            ),
            onPressed: _isValidMove ? () async {
              try {
                await api.moveSession(currentSession.sessionId, _selectedTableId!, _selectedSeat!);
                await _advanceOrFinish();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              }
            } : null,
            child: const Text("Move Player"),
          ),
      ],
    );
  }
}