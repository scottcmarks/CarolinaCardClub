class PlayerCategory {
  final int? playerCategoryId;
  final String name;
  final int rateIntervalId;
  final int? hourlyRateId;

  PlayerCategory({
    this.playerCategoryId,
    required this.name,
    this.rateIntervalId = 3,
    this.hourlyRateId,
  });

  PlayerCategory copyWith({
    int? playerCategoryId,
    String? name,
    int? rateIntervalId,
    int? hourlyRateId,
  }) {
    return PlayerCategory(
      playerCategoryId: playerCategoryId ?? this.playerCategoryId,
      name: name ?? this.name,
      rateIntervalId: rateIntervalId ?? this.rateIntervalId,
      hourlyRateId: hourlyRateId ?? this.hourlyRateId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'Player_Category_Id': playerCategoryId,
      'Name': name,
      'Rate_Interval_Id': rateIntervalId,
      'Hourly_Rate_Id': hourlyRateId,
    };
  }

  factory PlayerCategory.fromMap(Map<String, dynamic> map) {
    return PlayerCategory(
      playerCategoryId: map['Player_Category_Id'] as int?,
      name: map['Name'] as String,
      rateIntervalId: map['Rate_Interval_Id'] as int,
      hourlyRateId: map['Hourly_Rate_Id'] as int?,
    );
  }

  @override
  String toString() {
    return 'PlayerCategory(playerCategoryId: $playerCategoryId, name: $name, rateIntervalId: $rateIntervalId, hourlyRateId: $hourlyRateId)';
  }
}
