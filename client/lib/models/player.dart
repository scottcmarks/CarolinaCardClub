// client/lib/models/player.dart

class Player {
  final int? playerId;
  final String name;
  final int? playerCategoryId;
  final String? nickName;
  final String? flag;

  Player({
    this.playerId,
    required this.name,
    this.playerCategoryId,
    this.nickName,
    this.flag,
  });

  Player copyWith({
    int? playerId,
    String? name,
    int? playerCategoryId,
    String? nickName,
    String? flag,
  }) {
    return Player(
      playerId: playerId ?? this.playerId,
      name: name ?? this.name,
      playerCategoryId: playerCategoryId ?? this.playerCategoryId,
      nickName: nickName ?? this.nickName,
      flag: flag ?? this.flag,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'Player_Id': playerId,
      'Name': name,
      'Player_Category_Id': playerCategoryId,
      'NickName': nickName,
      'Flag': flag,
    };
  }

  factory Player.fromMap(Map<String, dynamic> map) {
    return Player(
      playerId: map['Player_Id'] as int?,
      name: map['Name'] as String,
      playerCategoryId: map['Player_Category_Id'] as int?,
      nickName: map['NickName'] as String?,
      flag: map['Flag'] as String?,
    );
  }

  @override
  String toString() {
    return 'Player(playerId: $playerId, name: $name, playerCategoryId: $playerCategoryId, nickName: $nickName, flag: $flag)';
  }
}