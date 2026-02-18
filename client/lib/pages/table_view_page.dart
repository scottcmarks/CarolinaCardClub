// client/lib/pages/table_view_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/api_provider.dart';
import '../models/poker_table.dart';
import '../widgets/location_selector_widget.dart';

class TableViewPage extends StatelessWidget {
  final PokerTable table;
  final int? pendingPlayerId;
  final int? highlightedSeat;

  const TableViewPage({Key? key, required this.table, this.pendingPlayerId, this.highlightedSeat}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final api = Provider.of<ApiProvider>(context);
    final occupancy = <int, String>{};
    for (var s in api.sessions.where((s) => s.stopTime == null && s.pokerTableId == table.pokerTableId)) {
      if (s.seatNumber != null) occupancy[s.seatNumber!] = s.name;
    }

    return LocationSelectorWidget(
      table: table,
      occupancy: occupancy,
      highlightedSeat: highlightedSeat,
      isSubPageMode: pendingPlayerId != null,
      onSeatSelected: (num) => Navigator.pop(context, num),
    );
  }
}