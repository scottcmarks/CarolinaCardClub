// client/lib/widgets/seat_selector_widget.dart

import 'package:flutter/material.dart';
import 'table_oval_widget.dart';

class SeatSelectorWidget extends StatefulWidget {
  final int? initialSeat;
  final int maxSeats;
  final Map<int, String> occupiedSeats; // UPDATED: Now receives a Map
  final String tableName;               // NEW: Needs the table name
  final Function(int) onSeatSelected;

  const SeatSelectorWidget({
    super.key,
    this.initialSeat,
    this.maxSeats = 10,
    this.occupiedSeats = const {},
    required this.tableName,
    required this.onSeatSelected,
  });

  @override
  State<SeatSelectorWidget> createState() => _SeatSelectorWidgetState();
}

class _SeatSelectorWidgetState extends State<SeatSelectorWidget> {
  int? _selectedSeat;

  @override
  void initState() {
    super.initState();
    _selectedSeat = widget.initialSeat;
  }

  @override
  void didUpdateWidget(covariant SeatSelectorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSeat != widget.initialSeat) {
      _selectedSeat = widget.initialSeat;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showTableMap(context),
      child: Container(
        width: 60,
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.blueGrey, width: 2),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(2, 2),
            )
          ],
        ),
        child: Text(
          _selectedSeat?.toString() ?? "-",
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey,
          ),
        ),
      ),
    );
  }

  void _showTableMap(BuildContext context) {
    // Initialize the controller with our current data
    final controller = TableOvalController(initialSeats: widget.occupiedSeats);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text("Select Seat at ${widget.tableName}"),
          content: AspectRatio(
            aspectRatio: 1.5, // Forces a nice wide oval shape
            child: SizedBox(
              width: 600,
              child: TableOvalWidget(
                tableName: widget.tableName,
                maxSeats: widget.maxSeats,
                controller: controller,
                selectedSeat: _selectedSeat,
                touched: (seat, occupantName) {
                  // Ignore taps on seats that are occupied or reserved
                  if (occupantName != null) return;

                  setState(() => _selectedSeat = seat);
                  widget.onSeatSelected(seat);
                  Navigator.pop(ctx);
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }
}