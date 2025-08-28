// models/player_selection_item.dart
class PlayerSelectionItem {
  final int playerId;
  final String name;
  final double balance; // Assuming balance can be null or a double

  PlayerSelectionItem({
    required this.playerId,
    required this.name,
    required this.balance,
  });

  // Factory method to create a PlayerSelectionItem from a map (database row)
  factory PlayerSelectionItem.fromMap(Map<String, dynamic> map) {
    return PlayerSelectionItem(
      playerId: map['Player_Id'],
      name: map['Name'] ?? 'Unnamed',
      balance: (map['Balance'] is int) ? (map['Balance'] as int).toDouble() : map['Balance'] ?? 0.0, // Handle potential int type for balance
    );
  }
}
