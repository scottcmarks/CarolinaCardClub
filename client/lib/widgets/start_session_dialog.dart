// client/lib/widgets/start_session_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player_selection_item.dart';
import '../models/session.dart';
import '../providers/api_provider.dart';
import '../providers/time_provider.dart';
import 'seat_selector_widget.dart';

class StartSessionDialog extends StatefulWidget {
  final PlayerSelectionItem player;
  const StartSessionDialog({super.key, required this.player});

  @override
  State<StartSessionDialog> createState() => _StartSessionDialogState();
}

class _StartSessionDialogState extends State<StartSessionDialog> {
  int? _selectedTableId;
  int? _selectedSeat;
  bool _isPrepaid = false;
  final TextEditingController _amountController = TextEditingController(text: "20");

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = Provider.of<ApiProvider>(context);
    final timeProvider = Provider.of<TimeProvider>(context);

    return AlertDialog(
      title: Text("Seat ${widget.player.name}"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(labelText: "Select Table"),
              // FIXED: Use initialValue to satisfy Flutter 3.33+ linter
              initialValue: _selectedTableId,
              items: api.tables.map((t) => DropdownMenuItem(
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
                occupiedSeats: api.getOccupiedSeatsForTable(_selectedTableId!),
                onSeatSelected: (seat) => setState(() => _selectedSeat = seat),
              ),

            SwitchListTile(
              title: const Text("Prepaid"),
              value: _isPrepaid,
              onChanged: (val) => setState(() => _isPrepaid = val),
            ),
            if (_isPrepaid)
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: "Amount (Dollars)"),
                keyboardType: TextInputType.number,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: () async {
            // FIXED: Capture Navigator before async gap to avoid linter warning
            final navigator = Navigator.of(context);

            final startEpoch = (timeProvider.currentTime.millisecondsSinceEpoch / 1000).round();
            final session = Session(
              sessionId: 0,
              playerId: widget.player.playerId,
              pokerTableId: _selectedTableId,
              seatNumber: _selectedSeat,
              startEpoch: startEpoch,
              isPrepaid: _isPrepaid,
              prepayAmount: _isPrepaid ? (int.tryParse(_amountController.text) ?? 0) : 0,
            );

            await api.addSession(session);

            // Close dialog using pre-captured navigator
            navigator.pop();
          },
          child: const Text("Start"),
        ),
      ],
    );
  }
}