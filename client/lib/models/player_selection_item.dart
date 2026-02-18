// client/lib/models/player_selection_item.dart

class PlayerSelectionItem {
  final int playerId;
  final String name;
  final int balance;
  final double hourlyRate;
  final int prepayHours;
  final bool isActive;

  PlayerSelectionItem({
    required this.playerId,
    required this.name,
    required this.balance,
    required this.hourlyRate,
    required this.prepayHours,
    required this.isActive,
  });

  factory PlayerSelectionItem.fromMap(Map<String, dynamic> map) {
    return PlayerSelectionItem(
      // Corrected to match your database schema singular naming
      playerId: (map['Player_Id'] ?? -1) as int,
      name: (map['Name'] ?? "") as String,
      // Robust conversion from num to int for Even Dollars logic
      balance: (map['Balance'] as num? ?? 0).toInt(),
      hourlyRate: (map['Hourly_Rate'] as num? ?? 0.0).toDouble(),
      prepayHours: (map['Prepay_Hours'] as num? ?? 0).toInt(),
      isActive: (map['Is_Active'] as int? ?? 0) == 1,
    );
  }
}