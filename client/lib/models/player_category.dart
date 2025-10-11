// client/lib/models/player_category.dart

class PlayerCategory {
  final int? playerCategoryId;
  final String name;
  final int rateIntervalId;

  PlayerCategory({
    this.playerCategoryId,
    required this.name,
    this.rateIntervalId = 3,
  });

  Map<String, dynamic> toMap() {
    return {
      'Player_Category_Id': playerCategoryId,
      'Name': name,
      'Rate_Interval_Id': rateIntervalId,
    };
  }

  factory PlayerCategory.fromMap(Map<String, dynamic> map) {
    return PlayerCategory(
      playerCategoryId: map['Player_Category_Id'] as int?,
      name: map['Name'] as String,
      rateIntervalId: map['Rate_Interval_Id'] as int,
    );
  }

  @override
  String toString() {
    return 'PlayerCategory(playerCategoryId: $playerCategoryId, name: $name, rateIntervalId: $rateIntervalId)';
  }
}