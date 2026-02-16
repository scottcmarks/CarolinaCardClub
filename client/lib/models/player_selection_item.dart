// models/player_selection_item.dart

class PlayerSelectionItem {
  final int playerId;
  final String name;
  final double balance;
  final bool isActive;
  final double hourlyRate;
  final int prepayHours;

  PlayerSelectionItem({
    required this.playerId,
    required this.name,
    required this.balance,
    this.isActive = false,
    this.hourlyRate = 5.0,
    this.prepayHours = 5,
  });

  factory PlayerSelectionItem.fromMap(Map<String, dynamic> map) {
    return PlayerSelectionItem(
      playerId: map['Player_Id'],
      name: map['Name'],
      balance: (map['Balance'] as num).toDouble(),
      isActive: (map['Is_Active'] as int) == 1,
      hourlyRate: (map['Hourly_Rate'] as num? ?? 5.0).toDouble(),
      prepayHours: (map['Prepay_Hours'] as int? ?? 5),
    );
  }
}