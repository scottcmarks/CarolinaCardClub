// client/lib/widgets/player_card.dart

import 'package:flutter/material.dart';
import '../models/player_selection_item.dart';

class PlayerCard extends StatelessWidget {
  final PlayerSelectionItem player;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget trailing; // NEW: Accept action buttons from the panel

  const PlayerCard({
    super.key,
    required this.player,
    required this.isSelected,
    required this.onTap,
    required this.trailing,
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
      clipBehavior: Clip.hardEdge,
      shape: isSelected
          ? RoundedRectangleBorder(
              side: BorderSide(color: Theme.of(context).primaryColor, width: 2.0),
              borderRadius: BorderRadius.circular(4.0),
            )
          : null,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
        title: Text(
          player.name,
          style: Theme.of(context).textTheme.titleLarge,
          softWrap: false,
          maxLines: 1,
        ),
        trailing: trailing, // Insert the buttons here!
      ),
    );
  }
}