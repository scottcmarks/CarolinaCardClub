// client/lib/widgets/player_picker_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/api_provider.dart';
import '../providers/time_provider.dart';

class PlayerPickerDialog extends StatelessWidget {
  final int? floorManagerPlayerId;
  final bool floorManagerOnly;

  const PlayerPickerDialog({
    super.key,
    this.floorManagerPlayerId,
    this.floorManagerOnly = false,
  });

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

    if (floorManagerOnly) {
      available = available
          .where((p) => p.playerId == floorManagerPlayerId)
          .toList();
    } else if (floorManagerPlayerId != null) {
      final fmIndex =
          available.indexWhere((p) => p.playerId == floorManagerPlayerId);
      if (fmIndex > 0) {
        final fm = available.removeAt(fmIndex);
        available.add(fm);
      }
    }

    return AlertDialog(
      title: const Text("Select Player"),
      content: SizedBox(
        width: double.maxFinite,
        child: available.isEmpty
            ? const Text(
                "No available players.",
                style: TextStyle(fontStyle: FontStyle.italic),
              )
            : ListView.builder(
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
      ],
    );
  }
}
