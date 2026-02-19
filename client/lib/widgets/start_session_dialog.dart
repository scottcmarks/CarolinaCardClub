// client/lib/widgets/start_session_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/api_provider.dart';
import '../models/player_selection_item.dart';
import '../models/session.dart';
import '../models/poker_table.dart';
import '../pages/table_view_page.dart';

class StartSessionDialog extends StatefulWidget {
  final PlayerSelectionItem player;
  const StartSessionDialog({Key? key, required this.player}) : super(key: key);

  @override
  State<StartSessionDialog> createState() => _StartSessionDialogState();
}

class _StartSessionDialogState extends State<StartSessionDialog> {
  int? _selectedTableId;
  int? _selectedSeatNumber;
  bool _isPrepaid = false;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final api = Provider.of<ApiProvider>(context, listen: false);
    final tables = api.pokerTables.where((t) => t.isActive).toList();
    final double calculatedPrepay = widget.player.hourlyRate * widget.player.prepayHours;

    return AlertDialog(
      title: Text("Seat ${widget.player.name}"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<int?>(
            decoration: const InputDecoration(labelText: "Table"),
            value: _selectedTableId,
            items: [
              const DropdownMenuItem(value: null, child: Text("Unseated")),
              ...tables.map((t) => DropdownMenuItem(value: t.pokerTableId, child: Text(t.name))),
            ],
            onChanged: _isSubmitting ? null : (v) => setState(() => _selectedTableId = v),
          ),
          SwitchListTile(
            title: const Text("Prepaid Session"),
            subtitle: Text(_isPrepaid ? "\$${calculatedPrepay.toInt()} upfront" : "Hourly billing"),
            value: _isPrepaid,
            onChanged: _isSubmitting ? null : (v) => setState(() => _isPrepaid = v),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: _isSubmitting ? null : () => _submit(api, calculatedPrepay),
          child: _isSubmitting ? const SizedBox(height: 15, width: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Text("Confirm"),
        ),
      ],
    );
  }

  Future<void> _submit(ApiProvider api, double prepay) async {
    setState(() => _isSubmitting = true);
    try {
      final s = Session(
        sessionId: 0,
        playerId: widget.player.playerId,
        pokerTableId: _selectedTableId,
        seatNumber: _selectedSeatNumber,
        startEpoch: (DateTime.now().millisecondsSinceEpoch ~/ 1000),
        isPrepaid: _isPrepaid,
        prepayAmount: _isPrepaid ? prepay : 0.0,
      );

      await api.addSession(s);
      if (_isPrepaid) await api.addPayment(playerId: widget.player.playerId, amount: prepay);

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        // Refresh local data so Burton shows $0 immediately
        await api.fetchPlayers();
        await api.fetchSessions();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}