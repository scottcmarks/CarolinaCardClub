// client/lib/widgets/location_selector_widget.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/api_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/time_provider.dart';
import '../models/poker_table.dart';
import '../models/session.dart';
import 'package:shared/shared.dart';

class LocationSelectorWidget extends StatefulWidget {
  final PokerTable table;
  final Map<int, String> occupancy;
  final Function(int seatNum) onSeatSelected;
  final bool isSubPageMode;
  final int? highlightedSeat;

  // Tablet mode callbacks — null means admin/sub-page mode
  final Function(Session session)? onStandUp;
  final Function(Session session)? onMarkAway;
  final Function(Session session)? onMarkReturn;
  final Function(Session session)? onMoveSeat;
  final Function(int seatNum)? onSeatPlayer;  // tablet-mode empty seat tap

  const LocationSelectorWidget({
    super.key,
    required this.table,
    required this.occupancy,
    required this.onSeatSelected,
    this.isSubPageMode = false,
    this.highlightedSeat,
    this.onStandUp,
    this.onMarkAway,
    this.onMarkReturn,
    this.onMoveSeat,
    this.onSeatPlayer,
  });

  bool get isTabletMode => onStandUp != null;

  @override
  State<LocationSelectorWidget> createState() => _LocationSelectorWidgetState();
}

class _LocationSelectorWidgetState extends State<LocationSelectorWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _flashController;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  // Determine the visual state of a seat for tablet mode
  _SeatState _getSeatState(int seatNum, ApiProvider api, TimeProvider time) {
    final session = api.sessions.firstWhere(
      (s) => s.pokerTableId == widget.table.pokerTableId &&
             s.seatNumber == seatNum &&
             s.stopTime == null,
      orElse: () => Session(sessionId: -1, playerId: -1, startEpoch: 0),
    );

    if (session.sessionId == -1) return _SeatState.empty;

    if (session.isAway) {
      final awaySeconds = time.nowEpoch - (session.awaySinceEpoch ?? time.nowEpoch);
      if (awaySeconds >= Shared.defaultAwayTimeoutSeconds) {
        return _SeatState.awayOverdue;
      }
      return _SeatState.away;
    }

    if (session.isPrepaid) return _SeatState.healthy;

    final playerMatches = api.players.where((p) => p.playerId == session.playerId);
    if (playerMatches.isEmpty) return _SeatState.healthy;
    final player = playerMatches.first;

    final balance = api.getDynamicBalance(player, time.nowEpoch);
    if (balance <= 0) return _SeatState.overdue;

    final warningThreshold = (Shared.defaultWarningPurchasedSecondsRemaining *
        session.hourlyRate / Shared.secondsPerHour).round();
    if (balance <= warningThreshold) return _SeatState.warning;

    return _SeatState.healthy;
  }

  String _abbreviateName(String name) {
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0];
    return '${parts[0]} ${parts[1][0]}.';
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettingsProvider>(context).currentSettings;
    final api = Provider.of<ApiProvider>(context);
    final time = Provider.of<TimeProvider>(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final double h = constraints.maxHeight;
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: w * Shared.tableWidthMultiplier,
              height: h * Shared.tableHeightMultiplier,
              decoration: BoxDecoration(
                color: Colors.green.shade900,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            ...List.generate(widget.table.capacity, (i) {
              int seatNum = i + 1;
              bool isReserved = (settings.floorManagerPlayerId != null &&
                  widget.table.pokerTableId == settings.floorManagerReservedTable &&
                  seatNum == settings.floorManagerReservedSeat);
              bool isManagerActive = settings.floorManagerPlayerId != null &&
                  api.sessions.any((s) =>
                      s.playerId == settings.floorManagerPlayerId &&
                      s.stopTime == null);
              bool showReservedIcon =
                  isReserved && !isManagerActive && widget.occupancy[seatNum] == null;

              if (widget.isTabletMode) {
                return _buildTabletSeat(seatNum, w, h, api, time);
              } else {
                return _buildSeat(seatNum, w, h, showReservedIcon);
              }
            }),
          ],
        );
      },
    );
  }

  // --- Sub-page / admin mode seat (original) ---

  Widget _buildSeat(int seatNum, double w, double h, bool showReserved) {
    double angle = (2 * math.pi * (seatNum - 1) / widget.table.capacity) - (math.pi / 2);
    return Transform.translate(
      offset: Offset(math.cos(angle) * (w * 0.4), math.sin(angle) * (h * 0.35)),
      child: GestureDetector(
        onTap: widget.occupancy[seatNum] == null ? () => widget.onSeatSelected(seatNum) : null,
        child: AnimatedBuilder(
          animation: _flashController,
          builder: (ctx, _) => Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: widget.occupancy[seatNum] != null ? Colors.red : Colors.white,
              shape: BoxShape.circle,
              boxShadow: seatNum == widget.highlightedSeat
                  ? [BoxShadow(color: Colors.cyanAccent, blurRadius: 10 * _flashController.value)]
                  : null,
            ),
            child: Center(
              child: showReserved
                  ? const Icon(Icons.verified_user, size: 20, color: Colors.blue)
                  : Text("$seatNum"),
            ),
          ),
        ),
      ),
    );
  }

  // --- Tablet mode seat ---

  Widget _buildTabletSeat(int seatNum, double w, double h, ApiProvider api, TimeProvider time) {
    final seatState = _getSeatState(seatNum, api, time);
    final double angle = (2 * math.pi * (seatNum - 1) / widget.table.capacity) - (math.pi / 2);

    // Find session for this seat
    final session = seatState != _SeatState.empty
        ? api.sessions.firstWhere(
            (s) => s.pokerTableId == widget.table.pokerTableId &&
                   s.seatNumber == seatNum &&
                   s.stopTime == null,
          )
        : null;

    return Transform.translate(
      offset: Offset(math.cos(angle) * (w * 0.4), math.sin(angle) * (h * 0.35)),
      child: GestureDetector(
        onTap: () => _handleTabletSeatTap(seatNum, seatState, session, api, time),
        child: AnimatedBuilder(
          animation: _flashController,
          builder: (ctx, _) {
            final color = _seatColor(seatState, _flashController.value);
            return Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black26, width: 1),
              ),
              child: _buildTabletSeatContent(seatNum, seatState, session, api, time),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTabletSeatContent(
    int seatNum,
    _SeatState state,
    Session? session,
    ApiProvider api,
    TimeProvider time,
  ) {
    if (state == _SeatState.empty) {
      return Center(
        child: Text(
          "$seatNum",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54),
        ),
      );
    }

    final player = session != null
        ? api.players.firstWhere(
            (p) => p.playerId == session.playerId,
            orElse: () => null as dynamic,
          )
        : null;

    final balance = (player != null && !session!.isPrepaid)
        ? api.getDynamicBalance(player, time.nowEpoch)
        : null;

    final name = session != null ? _abbreviateName(session.name) : '?';
    final textColor = (state == _SeatState.away) ? Colors.black54 : Colors.white;

    return Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (state == _SeatState.away || state == _SeatState.awayOverdue)
            const Icon(Icons.airline_seat_recline_extra, size: 12, color: Colors.white70),
          Text(
            name,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          if (balance != null)
            Text(
              '\$$balance',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            )
          else if (session!.isPrepaid)
            Text(
              'prepaid',
              style: TextStyle(fontSize: 8, color: textColor.withValues(alpha: 0.8)),
            ),
        ],
      ),
    );
  }

  Color _seatColor(_SeatState state, double flashValue) {
    switch (state) {
      case _SeatState.empty:
        return Colors.white;
      case _SeatState.healthy:
        return Colors.green.shade600;
      case _SeatState.warning:
        return Colors.amber.shade600;
      case _SeatState.overdue:
      case _SeatState.awayOverdue:
        // Flash between red and dark red
        return Color.lerp(Colors.red.shade700, Colors.red.shade300, flashValue)!;
      case _SeatState.away:
        return Colors.grey.shade500;
    }
  }

  void _handleTabletSeatTap(
    int seatNum,
    _SeatState state,
    Session? session,
    ApiProvider api,
    TimeProvider time,
  ) {
    if (state == _SeatState.empty) {
      widget.onSeatPlayer?.call(seatNum);
      return;
    }
    if (session == null) return;
    _showTabletSeatActions(session, state);
  }

  void _showTabletSeatActions(Session session, _SeatState state) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.title),
              title: Text(
                session.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            const Divider(height: 1),

            if (state == _SeatState.away || state == _SeatState.awayOverdue)
              ListTile(
                leading: const Icon(Icons.login, color: Colors.green),
                title: const Text('Mark Returned'),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onMarkReturn?.call(session);
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.airline_seat_recline_extra, color: Colors.grey),
                title: const Text('Mark Away'),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onMarkAway?.call(session);
                },
              ),

            ListTile(
              leading: const Icon(Icons.open_with, color: Colors.blue),
              title: const Text('Move Seat'),
              onTap: () {
                Navigator.pop(ctx);
                widget.onMoveSeat?.call(session);
              },
            ),

            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Stand Up'),
              onTap: () {
                Navigator.pop(ctx);
                widget.onStandUp?.call(session);
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

enum _SeatState { empty, healthy, warning, overdue, away, awayOverdue }
