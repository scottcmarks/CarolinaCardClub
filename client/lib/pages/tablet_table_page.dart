// client/lib/pages/tablet_table_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/api_provider.dart';
import '../providers/time_provider.dart';
import '../models/poker_table.dart';
import '../models/session.dart';
import '../models/player_selection_item.dart';
import '../providers/app_settings_provider.dart';
import '../widgets/table_oval_widget.dart';
import '../widgets/real_time_clock.dart';
import '../widgets/player_picker_dialog.dart';
import '../widgets/start_session_dialog.dart';
import 'package:shared/shared.dart';

class TabletTablePage extends StatefulWidget {
  final List<PokerTable> tables;
  final int initialIndex;

  const TabletTablePage({super.key, required this.tables, this.initialIndex = 0});

  @override
  State<TabletTablePage> createState() => _TabletTablePageState();
}

class _TabletTablePageState extends State<TabletTablePage> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ── Seat state calculation ─────────────────────────────────────────────────

  SeatState _getSeatState(int seatNum, PokerTable table, ApiProvider api, TimeProvider time) {
    final session = api.activeSessionAt(table.pokerTableId, seatNum);
    if (session == null) return SeatState.empty;

    if (session.isAway) {
      final awaySeconds =
          time.nowEpoch - (session.awaySinceEpoch ?? time.nowEpoch);
      return awaySeconds >= Shared.defaultAwayTimeoutSeconds
          ? SeatState.awayOverdue
          : SeatState.away;
    }

    if (session.isPrepaid) return SeatState.healthy;

    final playerMatches =
        api.players.where((p) => p.playerId == session.playerId);
    if (playerMatches.isEmpty) return SeatState.healthy;

    final balance = api.getDynamicBalance(playerMatches.first, time.nowEpoch);
    if (balance <= 0) return SeatState.overdue;

    final warningThreshold =
        (Shared.defaultWarningPurchasedSecondsRemaining *
                session.hourlyRate /
                Shared.secondsPerHour)
            .round();
    if (balance <= warningThreshold) return SeatState.warning;

    return SeatState.healthy;
  }

  // ── Build controller from current sessions ─────────────────────────────────

  TableOvalController _buildController(PokerTable table, ApiProvider api, TimeProvider time) {
    final controller = TableOvalController();
    for (final session in api.sessions.where((s) =>
        s.pokerTableId == table.pokerTableId &&
        s.stopTime == null &&
        s.seatNumber != null)) {
      final playerMatches =
          api.players.where((p) => p.playerId == session.playerId);
      final balance = (!session.isPrepaid && playerMatches.isNotEmpty)
          ? api.getDynamicBalance(playerMatches.first, time.nowEpoch)
          : null;

      controller.seatWithData(
        session.seatNumber!,
        SeatData(
          name: session.name,
          sessionId: session.sessionId,
          balance: balance,
          isPrepaid: session.isPrepaid,
          isAway: session.isAway,
          awaySinceEpoch: session.awaySinceEpoch,
          sessionStartEpoch: session.startEpoch,
        ),
      );
    }
    return controller;
  }

  @override
  Widget build(BuildContext context) {
    final api = Provider.of<ApiProvider>(context);
    final time = Provider.of<TimeProvider>(context);

    final idx = _currentIndex.clamp(0, widget.tables.length - 1);
    final hasPrev = idx > 0;
    final hasNext = idx < widget.tables.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: Stack(
          alignment: Alignment.center,
          children: [
            Text(widget.tables[idx].tableName, textAlign: TextAlign.center),
            if (hasPrev)
              Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  label: Text('← ${widget.tables[idx - 1].tableName}',
                      style: const TextStyle(fontSize: 12)),
                  padding: EdgeInsets.zero,
                  onPressed: () => _pageController.animateToPage(idx - 1,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut),
                ),
              ),
            if (hasNext)
              Align(
                alignment: Alignment.centerRight,
                child: ActionChip(
                  label: Text('${widget.tables[idx + 1].tableName} →',
                      style: const TextStyle(fontSize: 12)),
                  padding: EdgeInsets.zero,
                  onPressed: () => _pageController.animateToPage(idx + 1,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut),
                ),
              ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.blue.shade900),
                const SizedBox(width: 8),
                const RealTimeClock(),
              ],
            ),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemCount: widget.tables.length,
        itemBuilder: (ctx, pageIdx) {
          final table = widget.tables[pageIdx];
          final controller = _buildController(table, api, time);
          return TableOvalWidget(
            tableName: table.tableName,
            maxSeats: table.capacity,
            controller: controller,
            getSeatState: (seatNum) => _getSeatState(seatNum, table, api, time),
            getNowEpoch: () => time.nowEpoch,
            touched: (seatNum, occupantName) {
              final state = _getSeatState(seatNum, table, api, time);
              if (state == SeatState.empty) {
                _showSeatPlayer(context, seatNum, table);
              } else {
                final session = api.activeSessionAt(table.pokerTableId, seatNum)!;
                _showSeatActions(context, session, state, api, time, table);
              }
            },
          );
        },
      ),
    );
  }

  // ── Seat actions bottom sheet ──────────────────────────────────────────────

  void _showSeatActions(BuildContext context, Session session, SeatState state,
      ApiProvider api, TimeProvider time, PokerTable table) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: Text(session.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            const Divider(height: 1),
            if (state == SeatState.away || state == SeatState.awayOverdue)
              ListTile(
                leading: const Icon(Icons.login, color: Colors.green),
                title: const Text('Mark Returned'),
                onTap: () {
                  Navigator.pop(ctx);
                  _markReturn(context, session);
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.airline_seat_recline_extra,
                    color: Colors.grey),
                title: const Text('Mark Away'),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmMarkAway(context, session, time);
                },
              ),
            ListTile(
              leading: const Icon(Icons.open_with, color: Colors.blue),
              title: const Text('Move Seat'),
              onTap: () {
                Navigator.pop(ctx);
                _showMoveSeat(context, session, api, time, table);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Stand Up'),
              onTap: () {
                Navigator.pop(ctx);
                _confirmStandUp(context, session, time);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Stand Up ──────────────────────────────────────────────────────────────

  void _confirmStandUp(
      BuildContext context, Session session, TimeProvider time) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Stand Up: ${session.name}?"),
        content: const Text(
            "This will end the session and update the player's balance."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final api = Provider.of<ApiProvider>(context, listen: false);
              try {
                await api.stopSession(session.sessionId, time.nowEpoch);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text("Error: $e"),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text("Stand Up"),
          ),
        ],
      ),
    );
  }

  // ── Mark Away ─────────────────────────────────────────────────────────────

  void _confirmMarkAway(
      BuildContext context, Session session, TimeProvider time) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Mark Away: ${session.name}?"),
        content:
            const Text("Player's session will continue running while away."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final api = Provider.of<ApiProvider>(context, listen: false);
              try {
                await api.markAway(session.sessionId, time.nowEpoch);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text("Error: $e"),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text("Mark Away"),
          ),
        ],
      ),
    );
  }

  // ── Mark Return ───────────────────────────────────────────────────────────

  void _markReturn(BuildContext context, Session session) async {
    final api = Provider.of<ApiProvider>(context, listen: false);
    try {
      await api.markReturn(session.sessionId);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Move Seat ─────────────────────────────────────────────────────────────

  void _showMoveSeat(BuildContext context, Session session, ApiProvider api,
      TimeProvider time, PokerTable table) {
    final occupiedSeats = api.getOccupiedSeatsAndNamesForTable(
        table.pokerTableId,
        seatingPlayerId: session.playerId);

    showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Move ${session.name}"),
        content: AspectRatio(
          aspectRatio: 1.5,
          child: SizedBox(
            width: 600,
            child: TableOvalWidget(
              tableName: table.tableName,
              maxSeats: table.capacity,
              controller: TableOvalController(initialSeats: occupiedSeats),
              selectedSeat: session.seatNumber,
              touched: (seatNum, occupantName) {
                if (occupantName != null) return;
                Navigator.pop(ctx, seatNum);
              },
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel")),
        ],
      ),
    ).then((newSeat) async {
      if (newSeat == null || newSeat == session.seatNumber) return;
      try {
        await api.moveSession(
            session.sessionId, table.pokerTableId, newSeat, time.nowEpoch);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text("Error: $e"), backgroundColor: Colors.red),
          );
        }
      }
    });
  }

  // ── Seat a Player ─────────────────────────────────────────────────────────

  void _showSeatPlayer(BuildContext context, int seatNum, PokerTable table) async {
    final settings =
        Provider.of<AppSettingsProvider>(context, listen: false).currentSettings;
    final isReservedSeat = settings.isFloorManagerReservedSeat(table.pokerTableId, seatNum);

    final player = await showDialog<PlayerSelectionItem>(
      context: context,
      builder: (_) => PlayerPickerDialog(
        floorManagerPlayerId: settings.floorManagerPlayerId,
        floorManagerOnly: isReservedSeat,
      ),
    );
    if (player == null || !context.mounted) return;

    await showDialog<bool>(
      context: context,
      builder: (_) => StartSessionDialog(
        player: player,
        initialTableId: table.pokerTableId,
        initialSeat: seatNum,
      ),
    );
  }
}
