// client/lib/models/player_selection_item.dart

class PlayerSelectionItem {
  final int playerId;
  final String name;
  final int balance;      // Integer Dollars
  final bool isActive;    // Restored
  final int hourlyRate;   // Integer Dollars per hour
  final int prepayHours;  // Integer Hours

  PlayerSelectionItem({
    required this.playerId,
    required this.name,
    required this.balance,
    this.isActive = false,
    this.hourlyRate = 10,
    this.prepayHours = 0,
  });

  // Dual-compatibility getter for legacy code
  String get playerName => name;

  factory PlayerSelectionItem.fromJson(Map<String, dynamic> json) {
    return PlayerSelectionItem(
      playerId: json['playerId'] as int,
      name: (json['name'] ?? json['playerName'] ?? 'Unknown') as String,
      balance: (json['balance'] as num).toInt(),
      isActive: json['isActive'] ?? false,
      hourlyRate: (json['hourlyRate'] ?? 10).toInt(),
      prepayHours: (json['prepayHours'] ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'playerId': playerId,
    'name': name,
    'balance': balance,
    'isActive': isActive,
    'hourlyRate': hourlyRate,
    'prepayHours': prepayHours,
  };
}