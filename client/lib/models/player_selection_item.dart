// client/lib/models/player_selection_item.dart

class PlayerSelectionItem {
  final int playerId;
  final String name;
  final int balance;
  final bool isActive;
  final int hourlyRate;
  final int prepayHours;

  PlayerSelectionItem({
    required this.playerId,
    required this.name,
    required this.balance,
    this.isActive = false,
    this.hourlyRate = 10,
    this.prepayHours = 0,
  });

  String get playerName => name;

  factory PlayerSelectionItem.fromJson(Map<String, dynamic> json) {
    return PlayerSelectionItem(
      playerId: (json['playerId'] ?? json['Player_Id']) as int,
      name: (json['name'] ?? json['Name'] ?? json['playerName'] ?? 'Unknown') as String,
      balance: ((json['balance'] ?? json['Balance'] ?? 0) as num).toInt(),
      isActive: json['isActive'] ?? (json['Is_Active'] == 1),
      hourlyRate: ((json['hourlyRate'] ?? json['Hourly_Rate'] ?? 10) as num).toInt(),
      prepayHours: ((json['prepayHours'] ?? json['Prepay_Hours'] ?? 0) as num).toInt(),
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