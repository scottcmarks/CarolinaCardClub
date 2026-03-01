// client/lib/widgets/table_oval_widget.dart

import 'dart:math';
import 'package:flutter/material.dart';

/// The state controller that implements your requested functional members
class TableOvalController extends ChangeNotifier {
  final Map<int, String> _seats = {};

  TableOvalController({Map<int, String>? initialSeats}) {
    if (initialSeats != null) _seats.addAll(initialSeats);
  }

  // Returns the name of the player at the given seat, or null if empty
  String? name(int seat) => _seats[seat];

  // Action to seat a player dynamically
  void seat(int seat, String playerName) {
    _seats[seat] = playerName;
    notifyListeners();
  }

  // Action to unseat a player dynamically
  void unseat(int seat) {
    _seats.remove(seat);
    notifyListeners();
  }
}

class TableOvalWidget extends StatelessWidget {
  final String tableName;
  final int maxSeats;
  final TableOvalController controller;
  final Function(int seat, String? name) touched;
  final int? selectedSeat;

  const TableOvalWidget({
    super.key,
    required this.tableName,
    required this.maxSeats,
    required this.controller,
    required this.touched,
    this.selectedSeat,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;

            final centerX = width / 2;
            final centerY = height / 2;

            // The radius of the ellipse the cards will sit on.
            // We subtract ~40 to keep the cards inside the bounding box.
            final radiusX = (width / 2) - 40;
            final radiusY = (height / 2) - 40;

            List<Widget> children = [];

            // 1. Draw the physical table in the center
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
                    ]
                  ),
                  child: Center(
                    child: Text(
                      tableName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black45, blurRadius: 2, offset: Offset(1, 1))]
                      ),
                    ),
                  ),
                ),
              )
            );

            // 2. Draw the seat cards around the oval
            for (int i = 0; i < maxSeats; i++) {
              int seatNum = i + 1;

              // Distribute evenly around the circle, starting from the top (-pi/2)
              double angle = -pi / 2 + (2 * pi * i / maxSeats);

              // 35 is half the card width/height to perfectly center them on the line
              double x = centerX + radiusX * cos(angle) - 35;
              double y = centerY + radiusY * sin(angle) - 35;

              String? occupantName = controller.name(seatNum);
              bool isOccupied = occupantName != null;
              bool isReserved = occupantName == "Reserved";
              bool isSelected = selectedSeat == seatNum;

              // Determine styling based on state
              Color cardColor = isSelected
                  ? Colors.blueAccent
                  : (isReserved ? Colors.orange.shade100 : (isOccupied ? Colors.grey.shade300 : Colors.white));

              Color textColor = isSelected
                  ? Colors.white
                  : (isOccupied ? Colors.grey.shade600 : Colors.black87);

              children.add(
                Positioned(
                  left: x,
                  top: y,
                  child: GestureDetector(
                    onTap: () => touched(seatNum, occupantName),
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? Colors.blue.shade900 : Colors.blueGrey.shade300,
                          width: isSelected ? 3 : 1
                        ),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2,2))
                        ]
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("$seatNum", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                          if (isOccupied)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                occupantName,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isReserved ? FontWeight.bold : FontWeight.normal,
                                  color: isReserved ? Colors.orange.shade900 : textColor,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )
                        ],
                      ),
                    ),
                  ),
                )
              );
            }

            return Stack(clipBehavior: Clip.none, children: children);
          }
        );
      }
    );
  }
}