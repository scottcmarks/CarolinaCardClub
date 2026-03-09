// client/lib/widgets/player_picker_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/api_provider.dart';
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
      content: Column(
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
              Flexible(child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < available.length; i++) ...[
                      if (!available[i].isActive && (i == 0 || available[i - 1].isActive))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Container(height: 5, color: Colors.grey.shade400),
                        ),
                      ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: Text(
                          available[i].name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.pop(context, available[i]),
                      ),
                    ],
                  ],
                ),
              )),
          ],
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
