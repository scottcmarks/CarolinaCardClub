// client/lib/widgets/player_card.dart

import 'package:flutter/material.dart';
import '../models/player_selection_item.dart';

class PlayerCard extends StatelessWidget {
  final PlayerSelectionItem player;
  final bool isSelected;
  final VoidCallback onTap;

  const PlayerCard({
    super.key,
    required this.player,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color? cardColor;
    if (player.balance > 0) {
      cardColor = Colors.green.shade100;
    } else if (player.balance < 0) {
      cardColor = Colors.red.shade100;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      color: cardColor,
      clipBehavior: Clip.hardEdge, // Ensures splash effects are clipped to the card shape
      shape: isSelected
          ? RoundedRectangleBorder(
              side:
                  BorderSide(color: Theme.of(context).primaryColor, width: 2.0),
              borderRadius: BorderRadius.circular(4.0),
            )
          : null,
      child: ListTile(
        onTap: onTap, // FIX: onTap must be here to prevent the ListTile from "swallowing" the click
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
        title: Text(
          player.name,
          style: Theme.of(context).textTheme.titleLarge,
          softWrap: false,
          maxLines: 1,
        ),
      ),
    );
  }
}