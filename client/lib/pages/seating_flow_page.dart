// client/lib/pages/seating_flow_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/api_provider.dart';
import '../providers/app_settings_provider.dart';
import '../models/player_selection_item.dart';
import 'table_view_page.dart';

class SeatingFlowPage extends StatefulWidget {
  final PlayerSelectionItem player;
  const SeatingFlowPage({Key? key, required this.player}) : super(key: key);

  @override
  State<SeatingFlowPage> createState() => _SeatingFlowPageState();
}

class _SeatingFlowPageState extends State<SeatingFlowPage> {
  late PageController _pageController;
  int? _highlightedSeat;
  int _initialPage = 0;

  @override
  void initState() {
    super.initState();
    final api = Provider.of<ApiProvider>(context, listen: false);
    final settings = Provider.of<AppSettingsProvider>(context, listen: false).currentSettings;
    final activeTables = api.pokerTables.where((t) => t.isActive).toList();

    bool isFloorManager = settings.floorManagerPlayerId != null &&
                          widget.player.playerId == settings.floorManagerPlayerId;

    for (int i = 0; i < activeTables.length; i++) {
      final table = activeTables[i];
      final occupied = api.sessions
          .where((s) => s.stopTime == null && s.pokerTableId == table.pokerTableId)
          .map((s) => s.seatNumber).toSet();

      if (isFloorManager) {
        if (table.pokerTableId == settings.floorManagerReservedTable && !occupied.contains(settings.floorManagerReservedSeat)) {
          _initialPage = i;
          _highlightedSeat = settings.floorManagerReservedSeat;
          break;
        }
      } else {
        for (int s = 1; s <= table.capacity; s++) {
          bool isReserved = (table.pokerTableId == settings.floorManagerReservedTable && s == settings.floorManagerReservedSeat);
          if (!occupied.contains(s) && !isReserved) {
            _initialPage = i;
            _highlightedSeat = s;
            break;
          }
        }
      }
      if (_highlightedSeat != null) break;
    }
    _pageController = PageController(initialPage: _initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeTables = Provider.of<ApiProvider>(context).pokerTables.where((t) => t.isActive).toList();
    return Scaffold(
      appBar: AppBar(title: Text("Seating: ${widget.player.name}")),
      body: PageView.builder(
        controller: _pageController,
        itemCount: activeTables.length,
        itemBuilder: (ctx, idx) => TableViewPage(
          table: activeTables[idx],
          pendingPlayerId: widget.player.playerId,
          highlightedSeat: (idx == _initialPage) ? _highlightedSeat : null,
        ),
      ),
    );
  }
}