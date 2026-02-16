// client/lib/widgets/seat_selector_widget.dart

import 'package:flutter/material.dart';

class SeatSelectorWidget extends StatefulWidget {
  final int? initialSeat;
  final int maxSeats;
  final List<int> occupiedSeats;
  final Function(int) onSeatSelected;

  const SeatSelectorWidget({
    Key? key,
    this.initialSeat,
    this.maxSeats = 10,
    this.occupiedSeats = const [],
    required this.onSeatSelected,
  }) : super(key: key);

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
      onTap: () => _showKeypad(context),
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
              color: Colors.black.withOpacity(0.1),
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

  void _showKeypad(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Select Seat"),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.2,
              ),
              itemCount: widget.maxSeats,
              itemBuilder: (context, index) {
                final seatNum = index + 1;
                final isOccupied = widget.occupiedSeats.contains(seatNum);
                final isSelected = _selectedSeat == seatNum;

                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSelected
                        ? Colors.blueAccent
                        : (isOccupied ? Colors.grey.shade400 : Colors.grey.shade200),
                    foregroundColor: isSelected
                        ? Colors.white
                        : (isOccupied ? Colors.white60 : Colors.black),
                  ),
                  onPressed: isOccupied
                    ? null
                    : () {
                        setState(() => _selectedSeat = seatNum);
                        widget.onSeatSelected(seatNum);
                        Navigator.pop(ctx);
                      },
                  child: Text(
                    "$seatNum",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                );
              },
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
