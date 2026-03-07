// client/lib/pages/seating_flow_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/api_provider.dart';
import '../providers/app_settings_provider.dart';
import '../models/app_settings.dart';
import '../models/player_selection_item.dart';
import '../models/poker_table.dart';
import '../widgets/player_picker_dialog.dart';
import '../widgets/start_session_dialog.dart';
import 'table_view_page.dart';

class SeatingFlowPage extends StatefulWidget {
  final PlayerSelectionItem? player;   // null = table-first (pick player after seat)
  final int? initialTableId;           // start on this table (table-first flow)

  const SeatingFlowPage({super.key, this.player, this.initialTableId});

  @override
  State<SeatingFlowPage> createState() => _SeatingFlowPageState();
}

class _SeatingFlowPageState extends State<SeatingFlowPage> {
  late PageController _pageController;
  int? _highlightedSeat;
  int _initialPage = 0;

  // Returns only active tables that have at least one seat available.
  List<PokerTable> _availableTables(ApiProvider api, AppSettings settings) {
    return api.pokerTables.where((t) {
      if (!t.isActive) return false;
      final occupied = api.sessions
          .where((s) => s.stopTime == null && s.pokerTableId == t.pokerTableId)
          .map((s) => s.seatNumber)
          .toSet();
      final isFloorManager = widget.player != null &&
          settings.floorManagerPlayerId != null &&
          widget.player!.playerId == settings.floorManagerPlayerId;
      for (int s = 1; s <= t.capacity; s++) {
        if (occupied.contains(s)) continue;
        final isReserved = t.pokerTableId == settings.floorManagerReservedTable &&
            s == settings.floorManagerReservedSeat;
        if (isReserved && !isFloorManager) continue;
        return true;
      }
      return false;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    final api = Provider.of<ApiProvider>(context, listen: false);
    final settings = Provider.of<AppSettingsProvider>(context, listen: false).currentSettings;
    final tables = _availableTables(api, settings);

    if (widget.initialTableId != null) {
      // Table-first: start on the requested table.
      final idx = tables.indexWhere((t) => t.pokerTableId == widget.initialTableId);
      _initialPage = idx >= 0 ? idx : 0;
    } else {
      // Player-first: find the first table with an available seat and highlight it.
      final isFloorManager = widget.player != null &&
          settings.floorManagerPlayerId != null &&
          widget.player!.playerId == settings.floorManagerPlayerId;
      outer:
      for (int i = 0; i < tables.length; i++) {
        final table = tables[i];
        final occupied = api.sessions
            .where((s) => s.stopTime == null && s.pokerTableId == table.pokerTableId)
            .map((s) => s.seatNumber)
            .toSet();
        for (int s = 1; s <= table.capacity; s++) {
          if (occupied.contains(s)) continue;
          final isReserved = table.pokerTableId == settings.floorManagerReservedTable &&
              s == settings.floorManagerReservedSeat;
          if (isReserved && !isFloorManager) continue;
          _initialPage = i;
          _highlightedSeat = s;
          break outer;
        }
      }
    }

    _pageController = PageController(initialPage: _initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _onSeatChosen(int tableId, int seatNum) async {
    PlayerSelectionItem? player = widget.player;

    if (player == null) {
      final settings =
          Provider.of<AppSettingsProvider>(context, listen: false).currentSettings;
      player = await showDialog<PlayerSelectionItem>(
        context: context,
        builder: (_) => PlayerPickerDialog(
          floorManagerPlayerId: settings.floorManagerPlayerId,
        ),
      );
      if (player == null || !mounted) return;
    }

    final created = await showDialog<bool>(
      context: context,
      builder: (_) => StartSessionDialog(
        player: player!,
        initialTableId: tableId,
        initialSeat: seatNum,
      ),
    );

    if (created == true && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = Provider.of<ApiProvider>(context);
    final settings = Provider.of<AppSettingsProvider>(context).currentSettings;
    final tables = _availableTables(api, settings);

    final title = widget.player != null
        ? "Seating: ${widget.player!.name}"
        : "Select Seat";

    if (tables.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: Text("No tables with available seats.")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PageView.builder(
        controller: _pageController,
        itemCount: tables.length,
        itemBuilder: (ctx, idx) => TableViewPage(
          table: tables[idx],
          pendingPlayerId: widget.player?.playerId,
          highlightedSeat: idx == _initialPage ? _highlightedSeat : null,
          onSeatChosen: _onSeatChosen,
        ),
      ),
    );
  }
}