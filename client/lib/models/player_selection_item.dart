// client/lib/models/player_selection_item.dart

class PlayerSelectionItem {
  final int playerId;
  final String name;
  final int balance;
  final double hourlyRate; // Standardized as double
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

  // Standardized to fromJson to match the rest of the app's network logic
  factory PlayerSelectionItem.fromJson(Map<String, dynamic> json) {
    return PlayerSelectionItem(
      playerId: (json['Player_Id'] ?? -1) as int,
      name: (json['Name'] ?? "") as String,
      balance: (json['Balance'] as num? ?? 0).toInt(),
      // Force conversion to double to safely handle SQLite whole integers
      hourlyRate: (json['Hourly_Rate'] as num? ?? 0.0).toDouble(),
      prepayHours: (json['Prepay_Hours'] as num? ?? 0).toInt(),
      isActive: (json['Is_Active'] as int? ?? 0) == 1,
    );
  }
}