// client/lib/widgets/location_selector_widget.dart

import 'package:flutter/material.dart';
import '../models/poker_table.dart';
import 'seat_selector_widget.dart';

class LocationSelectorWidget extends StatefulWidget {
  final List<PokerTable> tables;
  final Map<int, List<int>> occupancyMap;
  final Function(int tableId, int? seatNum) onChanged;
  final bool requireSeat;

  const LocationSelectorWidget({
    Key? key,
    required this.tables,
    required this.onChanged,
    this.occupancyMap = const {},
    this.requireSeat = false,
  }) : super(key: key);

  @override
  State<LocationSelectorWidget> createState() => _LocationSelectorWidgetState();
}

class _LocationSelectorWidgetState extends State<LocationSelectorWidget> {
  late int _selectedTableId;
  int? _selectedSeat;

  @override
  void initState() {
    super.initState();
    // Intelligent Default: Pick first table with at least one empty seat
    if (widget.tables.isNotEmpty) {
      _selectedTableId = widget.tables.first.pokerTableId;
      for (var t in widget.tables) {
         final occupied = widget.occupancyMap[t.pokerTableId] ?? [];
         if (occupied.length < t.capacity) {
           _selectedTableId = t.pokerTableId;
           break;
         }
      }
    } else {
      _selectedTableId = -1;
    }
  }

  void _emitChange() {
    widget.onChanged(_selectedTableId, _selectedSeat);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tables.isEmpty) {
      return const Text("No tables available", style: TextStyle(color: Colors.red));
    }

    final occupiedSeats = widget.occupancyMap[_selectedTableId] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Table:", style: TextStyle(fontWeight: FontWeight.bold)),
        Container(
          margin: const EdgeInsets.only(top: 4, bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedTableId,
              isExpanded: true,
              items: widget.tables.map((t) {
                // Visualize full tables in dropdown
                final count = (widget.occupancyMap[t.pokerTableId] ?? []).length;
                final isFull = count >= t.capacity;
                final label = isFull ? "${t.name} (Full)" : t.name;

                return DropdownMenuItem(
                  value: t.pokerTableId,
                  enabled: !isFull, // Disable selection if full
                  child: Text(label, style: TextStyle(color: isFull ? Colors.grey : Colors.black))
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedTableId = val;
                    _selectedSeat = null;
                  });
                  _emitChange();
                }
              },
            ),
          ),
        ),

        Row(
          children: [
            const Text("Seat:  ", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            SeatSelectorWidget(
              maxSeats: 10, // Could fetch specific capacity if passed
              occupiedSeats: occupiedSeats,
              onSeatSelected: (seat) {
                setState(() => _selectedSeat = seat);
                _emitChange();
              },
            ),

            if (_selectedSeat != null && !widget.requireSeat) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.clear, color: Colors.grey),
                onPressed: () {
                  setState(() => _selectedSeat = null);
                  _emitChange();
                },
                tooltip: "Stand Up (No Seat)",
              )
            ]
          ],
        ),
      ],
    );
  }
}