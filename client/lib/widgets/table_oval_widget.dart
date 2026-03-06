// client/lib/widgets/table_oval_widget.dart

import 'dart:math';
import 'package:flutter/material.dart';

// ── Seat data ────────────────────────────────────────────────────────────────

class SeatData {
  final String name;
  final int? sessionId;
  final int? balance;       // null = prepaid or no session
  final bool isPrepaid;
  final bool isAway;
  final int? awaySinceEpoch;
  final int? sessionStartEpoch;

  const SeatData({
    required this.name,
    this.sessionId,
    this.balance,
    this.isPrepaid = false,
    this.isAway = false,
    this.awaySinceEpoch,
    this.sessionStartEpoch,
  });
}

// ── Controller ───────────────────────────────────────────────────────────────

class TableOvalController extends ChangeNotifier {
  final Map<int, SeatData> _seats = {};

  TableOvalController({Map<int, String>? initialSeats}) {
    if (initialSeats != null) {
      for (final e in initialSeats.entries) {
        _seats[e.key] = SeatData(name: e.value);
      }
    }
  }

  // Simple name lookup — preserves SeatSelectorWidget compatibility
  String? name(int seat) => _seats[seat]?.name;

  // Full data lookup for tablet mode
  SeatData? data(int seat) => _seats[seat];

  bool isOccupied(int seat) => _seats.containsKey(seat);

  void seat(int seat, String playerName) {
    _seats[seat] = SeatData(name: playerName);
    notifyListeners();
  }

  void seatWithData(int seat, SeatData data) {
    _seats[seat] = data;
    notifyListeners();
  }

  void unseat(int seat) {
    _seats.remove(seat);
    notifyListeners();
  }

  void updateAll(Map<int, SeatData> newSeats) {
    _seats
      ..clear()
      ..addAll(newSeats);
    notifyListeners();
  }
}

// ── Seat state ────────────────────────────────────────────────────────────────

enum SeatState { empty, healthy, warning, overdue, away, awayOverdue }

// ── Widget ────────────────────────────────────────────────────────────────────

class TableOvalWidget extends StatefulWidget {
  final String tableName;
  final int maxSeats;
  final TableOvalController controller;
  final Function(int seat, String? name) touched;
  final int? selectedSeat;

  // Tablet mode — when provided, enables rich display and action callbacks
  final int Function(int seat)? getBalance;
  final SeatState Function(int seat)? getSeatState;
  final int Function()? getNowEpoch;

  const TableOvalWidget({
    super.key,
    required this.tableName,
    required this.maxSeats,
    required this.controller,
    required this.touched,
    this.selectedSeat,
    this.getBalance,
    this.getSeatState,
    this.getNowEpoch,
  });

  bool get isTabletMode => getSeatState != null;

  @override
  State<TableOvalWidget> createState() => _TableOvalWidgetState();
}

class _TableOvalWidgetState extends State<TableOvalWidget>
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

  String _formatDuration(int startEpoch, int nowEpoch) {
    final diff = nowEpoch - startEpoch;
    if (diff <= 0) return "0h00m";
    final hours = diff ~/ 3600;
    final minutes = (diff % 3600) ~/ 60;
    return "${hours}h${minutes.toString().padLeft(2, '0')}m";
  }

  String _abbreviateName(String name) {
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0];
    return '${parts[0]} ${parts[1][0]}.';
  }

  Color _seatColor(SeatState state, double flashValue) {
    switch (state) {
      case SeatState.empty:
        return Colors.white;
      case SeatState.healthy:
        return Colors.green.shade600;
      case SeatState.warning:
        return Colors.amber.shade600;
      case SeatState.overdue:
      case SeatState.awayOverdue:
        return Color.lerp(Colors.red.shade700, Colors.red.shade300, flashValue)!;
      case SeatState.away:
        return Colors.grey.shade500;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        return LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final centerX = width / 2;
          final centerY = height / 2;
          final radiusX = (width / 2) - 40;
          final radiusY = (height / 2) - 40;

          List<Widget> children = [];

          // Table oval
          children.add(
            Positioned(
              left: 70, right: 70, top: 70, bottom: 70,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.green.shade800,
                  borderRadius: BorderRadius.all(Radius.elliptical(radiusX, radiusY)),
                  border: Border.all(color: Colors.brown.shade900, width: 6),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))
                  ],
                ),
                child: Center(
                  child: Text(
                    widget.tableName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black45, blurRadius: 2, offset: Offset(1, 1))],
                    ),
                  ),
                ),
              ),
            ),
          );

          // Seats
          for (int i = 0; i < widget.maxSeats; i++) {
            final seatNum = i + 1;
            final angle = -pi / 2 + (2 * pi * i / widget.maxSeats);
            const seatSize = 90.0;
            const tabletSeatSize = 95.0;
            final size = widget.isTabletMode ? tabletSeatSize : seatSize;
            final half = size / 2;
            final orbitScale = widget.isTabletMode ? 0.85 : 1.0;
            final x = centerX + radiusX * orbitScale * cos(angle) - half;
            final y = centerY + radiusY * orbitScale * sin(angle) - half;

            final occupantName = widget.controller.name(seatNum);
            final seatData = widget.controller.data(seatNum);
            final isOccupied = occupantName != null;

            children.add(
              Positioned(
                left: x,
                top: y,
                child: widget.isTabletMode
                    ? _buildTabletSeat(seatNum, size, seatData)
                    : _buildSelectorSeat(seatNum, size, occupantName, isOccupied),
              ),
            );
          }

          return AnimatedBuilder(
            animation: _flashController,
            builder: (ctx, _) => Stack(clipBehavior: Clip.none, children: children),
          );
        });
      },
    );
  }

  // ── Selector mode seat (original style) ──────────────────────────────────

  Widget _buildSelectorSeat(int seatNum, double size, String? occupantName, bool isOccupied) {
    final isReserved = occupantName == "Reserved";
    final isSelected = widget.selectedSeat == seatNum;

    final cardColor = isSelected
        ? Colors.blueAccent
        : (isReserved ? Colors.orange.shade100 : (isOccupied ? Colors.grey.shade300 : Colors.white));
    final textColor = isSelected
        ? Colors.white
        : (isOccupied ? Colors.grey.shade600 : Colors.black87);

    return GestureDetector(
      onTap: () => widget.touched(seatNum, occupantName),
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue.shade900 : Colors.blueGrey.shade300,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2))],
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("$seatNum",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
            if (isOccupied)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  occupantName!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isReserved ? FontWeight.bold : FontWeight.normal,
                    color: isReserved ? Colors.orange.shade900 : textColor,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Tablet mode seat ──────────────────────────────────────────────────────

  Widget _buildTabletSeat(int seatNum, double size, SeatData? data) {
    final state = widget.getSeatState!(seatNum);
    final color = _seatColor(state, _flashController.value);
    final textColor = state == SeatState.away ? Colors.black54 : Colors.white;
    final isAway = state == SeatState.away || state == SeatState.awayOverdue;
    final nowEpoch = widget.getNowEpoch!();

    return GestureDetector(
      onTap: () => widget.touched(seatNum, data?.name),
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black26, width: 1),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2))],
        ),
        child: data == null
            ? Center(
                child: Text("$seatNum",
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black54)),
              )
            : Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isAway)
                      Icon(Icons.airline_seat_recline_extra, size: 11,
                          color: textColor.withValues(alpha: 0.8)),
                    Text(
                      _abbreviateName(data.name),
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: textColor),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if (data.sessionStartEpoch != null)
                      Text(
                        _formatDuration(data.sessionStartEpoch!, nowEpoch),
                        style: TextStyle(fontSize: 8, color: textColor.withValues(alpha: 0.85)),
                      ),
                    if (data.isPrepaid)
                      Text("prepaid",
                          style: TextStyle(fontSize: 8, color: textColor.withValues(alpha: 0.7)))
                    else if (data.balance != null)
                      Text(
                        "Bal: \$${data.balance}",
                        style: TextStyle(
                            fontSize: 9, fontWeight: FontWeight.bold, color: textColor),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
