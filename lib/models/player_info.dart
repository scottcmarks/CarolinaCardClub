// Note: This table seems redundant if Player model already captures Name.
// It might be for specific historical reasons or a simplified view of player data.
class PlayerInfo {
  final int? playerId;
  final String? name;

  PlayerInfo({
    this.playerId,
    this.name,
  });

  PlayerInfo copyWith({
    int? playerId,
    String? name,
  }) {
    return PlayerInfo(
      playerId: playerId ?? this.playerId,
      name: name ?? this.name,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'Player_Id': playerId,
      'Name': name,
    };
  }

  factory PlayerInfo.fromMap(Map<String, dynamic> map) {
    return PlayerInfo(
      playerId: map['Player_Id'] as int?,
      name: map['Name'] as String?,
    );
  }

  @override
  String toString() {
    return 'PlayerInfo(playerId: $playerId, name: $name)';
  }
}
