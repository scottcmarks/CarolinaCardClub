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

enum SeatState { empty, reserved, healthy, warning, overdue, away, awayOverdue }

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
      case SeatState.reserved:
        return Colors.orange.shade300;
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

          // Full felt-green background
          children.add(Positioned.fill(child: ColoredBox(color: Colors.green.shade800)));

          // Table superellipse (Lamé curve, n=3)
          children.add(
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(70),
                child: CustomPaint(
                  painter: const _SuperellipsePainter(),
                  child: Center(
                    child: Text(
                      widget.tableName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFF7BAFD4).withValues(alpha: 0.50),
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );

          // Seats — size proportionally to orbit so both tablets fit cleanly
          const orbitScale = 0.78;
          final slotDist = min(radiusX, radiusY) * orbitScale * 2 * sin(pi / widget.maxSeats);
          final seatH = widget.isTabletMode
              ? (slotDist * 0.70).clamp(60.0, 180.0)
              : 75.0;
          final seatW = widget.isTabletMode ? seatH * 1.612 : 120.0;

          for (int i = 0; i < widget.maxSeats; i++) {
            final seatNum = i + 1;
            final angle = pi + 2 * pi * (i - 6) / widget.maxSeats;
            final x = centerX + radiusX * orbitScale * cos(angle) - seatW / 2;
            final y = centerY + radiusY * orbitScale * sin(angle) - seatH / 2;

            final occupantName = widget.controller.name(seatNum);
            final seatData = widget.controller.data(seatNum);
            final isOccupied = occupantName != null;

            children.add(
              Positioned(
                left: x,
                top: y,
                child: widget.isTabletMode
                    ? _buildTabletSeat(seatNum, seatW, seatH, seatData)
                    : _buildSelectorSeat(seatNum, seatW, seatH, occupantName, isOccupied),
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

  Widget _buildSelectorSeat(int seatNum, double w, double h, String? occupantName, bool isOccupied) {
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
        width: w, height: h,
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
            if (isReserved)
              Icon(Icons.verified_user, size: 20, color: Colors.blue.shade700)
            else if (isOccupied)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  occupantName!,
                  style: TextStyle(fontSize: 10, color: textColor),
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

  Widget _buildTabletSeat(int seatNum, double w, double h, SeatData? data) {
    final state = widget.getSeatState!(seatNum);
    final color = _seatColor(state, _flashController.value);
    final isReserved = state == SeatState.reserved;
    final textColor = (state == SeatState.away || isReserved) ? Colors.black54 : Colors.white;
    final isAway = state == SeatState.away || state == SeatState.awayOverdue;
    final nowEpoch = widget.getNowEpoch!();

    return GestureDetector(
      onTap: () => widget.touched(seatNum, data?.name),
      child: Container(
        width: w, height: h,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black26, width: 1),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2))],
        ),
        child: isReserved
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("$seatNum",
                      style: TextStyle(
                          fontSize: h * 0.188, fontWeight: FontWeight.bold, color: Colors.black54)),
                  Icon(Icons.verified_user, size: h * 0.242, color: Colors.black45),
                ],
              )
            : data == null
            ? Center(
                child: Text("$seatNum",
                    style: TextStyle(
                        fontSize: h * 0.296, fontWeight: FontWeight.bold, color: Colors.black54)),
              )
            : Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isAway)
                      Icon(Icons.airline_seat_recline_extra, size: h * 0.143,
                          color: textColor.withValues(alpha: 0.8)),
                    Text(
                      _abbreviateName(data.name),
                      style: TextStyle(fontSize: h * 0.150, fontWeight: FontWeight.w600, color: textColor),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if (data.isPrepaid)
                      Text("prepaid",
                          style: TextStyle(fontSize: h * 0.099, color: textColor.withValues(alpha: 0.7)))
                    else if (data.sessionStartEpoch != null)
                      Text(
                        data.balance != null
                            ? '${_formatDuration(data.sessionStartEpoch!, nowEpoch)}  Bal: \$${data.balance}'
                            : _formatDuration(data.sessionStartEpoch!, nowEpoch),
                        style: TextStyle(fontSize: h * 0.107, color: textColor.withValues(alpha: 0.85)),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ── Superellipse (Lamé curve, n=3) table painter ──────────────────────────────

class _SuperellipsePainter extends CustomPainter {
  const _SuperellipsePainter();

  // Parametric superellipse: x(t) = a·sign(cos t)·|cos t|^(2/n), n=3 → exp=2/3
  static Path _buildPath(Size size) {
    const exp = 2.0 / 3.0;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final a = size.width / 2;
    final b = size.height / 2;
    const steps = 360;
    final path = Path();
    for (int i = 0; i <= steps; i++) {
      final t = 2 * pi * i / steps;
      final cosT = cos(t);
      final sinT = sin(t);
      final x = cx + a * cosT.sign * pow(cosT.abs(), exp).toDouble();
      final y = cy + b * sinT.sign * pow(sinT.abs(), exp).toDouble();
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath(size);
    canvas.drawShadow(path.shift(const Offset(0, 5)), Colors.black26, 10, false);
    canvas.drawPath(path, Paint()..color = Colors.green.shade800);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );
  }

  @override
  bool shouldRepaint(_SuperellipsePainter oldDelegate) => false;
}
