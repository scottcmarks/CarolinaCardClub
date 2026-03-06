// client/lib/pages/table_view_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/api_provider.dart';
import '../providers/app_settings_provider.dart';
import '../models/poker_table.dart';
import '../widgets/table_oval_widget.dart';

class TableViewPage extends StatelessWidget {
  final PokerTable table;
  final int? pendingPlayerId;
  final int? highlightedSeat;
  final void Function(int tableId, int seatNum)? onSeatChosen;

  const TableViewPage({
    super.key,
    required this.table,
    this.pendingPlayerId,
    this.highlightedSeat,
    this.onSeatChosen,
  });

  @override
  Widget build(BuildContext context) {
    final api = Provider.of<ApiProvider>(context);
    final settings = Provider.of<AppSettingsProvider>(context).currentSettings;

    final controller = TableOvalController(
      initialSeats: Map.fromEntries(
        api.sessions
            .where((s) => s.stopTime == null &&
                s.pokerTableId == table.pokerTableId &&
                s.seatNumber != null)
            .map((s) => MapEntry(s.seatNumber!, s.name)),
      ),
    );

    // Mark reserved seat if floor manager is not currently seated
    if (settings.floorManagerPlayerId != null &&
        table.pokerTableId == settings.floorManagerReservedTable) {
      final isManagerSeated = api.sessions.any(
        (s) => s.playerId == settings.floorManagerPlayerId && s.stopTime == null,
      );
      if (!isManagerSeated) {
        controller.seat(settings.floorManagerReservedSeat, 'Reserved');
      }
    }

    return TableOvalWidget(
      tableName: table.tableName,
      maxSeats: table.capacity,
      controller: controller,
      selectedSeat: highlightedSeat,
      touched: (seatNum, occupantName) {
        if (occupantName != null) return; // occupied or reserved — not selectable
        if (onSeatChosen != null) {
          onSeatChosen!(table.pokerTableId, seatNum);
        } else {
          Navigator.pop(context, seatNum);
        }
      },
    );
  }
}