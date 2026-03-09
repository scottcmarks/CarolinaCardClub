// client/lib/widgets/player_card.dart

import 'package:flutter/material.dart';
import '../models/player_selection_item.dart';

class PlayerCard extends StatelessWidget {
  final PlayerSelectionItem player;
  final int dynamicBalance;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget trailing;

  const PlayerCard({
    super.key,
    required this.player,
    required this.dynamicBalance,
    required this.isSelected,
    required this.onTap,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    Color? cardColor;
    if (dynamicBalance > 0) {
      cardColor = Colors.green.shade100;
    } else if (dynamicBalance < 0) {
      cardColor = Colors.red.shade200;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
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
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
        title: Text(
          player.name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: trailing, // Insert the buttons here!
      ),
    );
  }
}