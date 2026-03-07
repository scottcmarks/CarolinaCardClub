// client/lib/widgets/player_picker_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/api_provider.dart';
import '../providers/time_provider.dart';
import 'name_filter_keyboard.dart';

class PlayerPickerDialog extends StatefulWidget {
  final int? floorManagerPlayerId;
  final bool floorManagerOnly;

  const PlayerPickerDialog({
    super.key,
    this.floorManagerPlayerId,
    this.floorManagerOnly = false,
  });

  @override
  State<PlayerPickerDialog> createState() => _PlayerPickerDialogState();
}

class _PlayerPickerDialogState extends State<PlayerPickerDialog> {
  bool _showKeyboard = false;
  String _nameFilter = '';

  @override
  Widget build(BuildContext context) {
    final api = Provider.of<ApiProvider>(context, listen: false);
    final timeProvider = Provider.of<TimeProvider>(context, listen: false);

    final activePlayerIds = api.sessions
        .where((s) => s.stopTime == null)
        .map((s) => s.playerId)
        .toSet();

    var available = api.players
        .where((p) => !activePlayerIds.contains(p.playerId))
        .toList();

    if (widget.floorManagerOnly) {
      available = available
          .where((p) => p.playerId == widget.floorManagerPlayerId)
          .toList();
    } else if (widget.floorManagerPlayerId != null) {
      final fmIndex =
          available.indexWhere((p) => p.playerId == widget.floorManagerPlayerId);
      if (fmIndex > 0) {
        final fm = available.removeAt(fmIndex);
        available.add(fm);
      }
    }

    if (_nameFilter.isNotEmpty) {
      available = available
          .where((p) => p.name.toLowerCase().startsWith(_nameFilter))
          .toList();
    }

    return AlertDialog(
      title: Row(
        children: [
          const Text("Select Player"),
          const Spacer(),
          IconButton(
            icon: _showKeyboard
                ? const Icon(Icons.close)
                : const Text('?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            tooltip: 'Filter by name',
            onPressed: () => setState(() {
              _showKeyboard = !_showKeyboard;
              if (!_showKeyboard) _nameFilter = '';
            }),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_showKeyboard)
              NameFilterKeyboard(
                filter: _nameFilter,
                onFilterChanged: (f) => setState(() => _nameFilter = f),
              ),
            if (available.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  "No available players.",
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: available.length,
                  itemBuilder: (ctx, i) {
                    final player = available[i];
                    final balance = api.getDynamicBalance(player, timeProvider.nowEpoch);
                    return ListTile(
                      title: Text(player.name),
                      trailing: Text(
                        '\$$balance',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: balance < 0 ? Colors.red : Colors.green,
                        ),
                      ),
                      onTap: () => Navigator.pop(context, player),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
      ],
    );
  }
}
