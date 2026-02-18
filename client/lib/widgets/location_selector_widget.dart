// client/lib/widgets/location_selector_widget.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/api_provider.dart';
import '../providers/app_settings_provider.dart';
import '../models/poker_table.dart';

class LocationSelectorWidget extends StatefulWidget {
  final PokerTable table;
  final Map<int, String> occupancy;
  final Function(int seatNum) onSeatSelected;
  final bool isSubPageMode;
  final int? highlightedSeat;

  const LocationSelectorWidget({
    Key? key, required this.table, required this.occupancy, required this.onSeatSelected,
    this.isSubPageMode = false, this.highlightedSeat,
  }) : super(key: key);

  @override
  State<LocationSelectorWidget> createState() => _LocationSelectorWidgetState();
}

class _LocationSelectorWidgetState extends State<LocationSelectorWidget> with SingleTickerProviderStateMixin {
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettingsProvider>(context).currentSettings;
    final api = Provider.of<ApiProvider>(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final double h = constraints.maxHeight;
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(width: w * 0.75, height: h * 0.65, decoration: BoxDecoration(color: Colors.green.shade900, borderRadius: BorderRadius.circular(100))),
            ...List.generate(widget.table.capacity, (i) {
              int seatNum = i + 1;
              bool isReserved = (settings.floorManagerPlayerId != null &&
                                 widget.table.pokerTableId == settings.floorManagerReservedTable &&
                                 seatNum == settings.floorManagerReservedSeat);
              bool isManagerActive = settings.floorManagerPlayerId != null &&
                                     api.sessions.any((s) => s.playerId == settings.floorManagerPlayerId && s.stopTime == null);
              bool showReservedIcon = isReserved && !isManagerActive && widget.occupancy[seatNum] == null;

              return _buildSeat(seatNum, w, h, showReservedIcon);
            }),
          ],
        );
      },
    );
  }

  Widget _buildSeat(int seatNum, double w, double h, bool showReserved) {
    double angle = (2 * math.pi * (seatNum - 1) / widget.table.capacity) - (math.pi / 2);
    return Transform.translate(
      offset: Offset(math.cos(angle) * (w * 0.4), math.sin(angle) * (h * 0.35)),
      child: GestureDetector(
        onTap: widget.occupancy[seatNum] == null ? () => widget.onSeatSelected(seatNum) : null,
        child: AnimatedBuilder(
          animation: _glowController,
          builder: (ctx, _) => Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: widget.occupancy[seatNum] != null ? Colors.red : Colors.white,
              shape: BoxShape.circle,
              boxShadow: seatNum == widget.highlightedSeat ? [BoxShadow(color: Colors.cyanAccent, blurRadius: 10 * _glowController.value)] : null,
            ),
            child: Center(child: showReserved ? const Icon(Icons.verified_user, size: 20, color: Colors.blue) : Text("$seatNum")),
          ),
        ),
      ),
    );
  }
}