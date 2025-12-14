// models/player_selection_item.dart
class PlayerSelectionItem {
  final int playerId;
  final String name;
  final double balance;
  final bool hasActiveSession; // Renamed from isActive

  PlayerSelectionItem({
    required this.playerId,
    required this.name,
    required this.balance,
    required this.hasActiveSession, // Renamed in constructor
  });

  // Factory method to create a PlayerSelectionItem from a map (database row)
  factory PlayerSelectionItem.fromMap(Map<String, dynamic> map) {
    return PlayerSelectionItem(
      playerId: map['Player_Id'],
      name: map['Name'] ?? 'Unnamed',
      balance: (map['Balance'] is int)
          ? (map['Balance'] as int).toDouble()
          : map['Balance'] ?? 0.0,
      // Logic now assigns to the renamed field
      hasActiveSession: (map['Active'] ?? 0) == 1,
    );
  }
}
