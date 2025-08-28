class Player {
  final int? playerId;
  final int playedSuperBowl;
  final String name;
  final String? emailAddress;
  final String? phoneNumber;
  final String? otherPhoneNumber1;
  final String? otherPhoneNumber2;
  final String? otherPhoneNumber3;
  final int? playerCategoryId;
  final String? nickName;
  final String? flag;

  Player({
    this.playerId,
    this.playedSuperBowl = 0,
    required this.name,
    this.emailAddress,
    this.phoneNumber,
    this.otherPhoneNumber1,
    this.otherPhoneNumber2,
    this.otherPhoneNumber3,
    this.playerCategoryId,
    this.nickName,
    this.flag,
  });

  Player copyWith({
    int? playerId,
    int? playedSuperBowl,
    String? name,
    String? emailAddress,
    String? phoneNumber,
    String? otherPhoneNumber1,
    String? otherPhoneNumber2,
    String? otherPhoneNumber3,
    int? playerCategoryId,
    String? nickName,
    String? flag,
  }) {
    return Player(
      playerId: playerId ?? this.playerId,
      playedSuperBowl: playedSuperBowl ?? this.playedSuperBowl,
      name: name ?? this.name,
      emailAddress: emailAddress ?? this.emailAddress,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      otherPhoneNumber1: otherPhoneNumber1 ?? this.otherPhoneNumber1,
      otherPhoneNumber2: otherPhoneNumber2 ?? this.otherPhoneNumber2,
      otherPhoneNumber3: otherPhoneNumber3 ?? this.otherPhoneNumber3,
      playerCategoryId: playerCategoryId ?? this.playerCategoryId,
      nickName: nickName ?? this.nickName,
      flag: flag ?? this.flag,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'Player_Id': playerId,
      'Played_Super_Bowl': playedSuperBowl,
      'Name': name,
      'Email_address': emailAddress,
      'Phone_number': phoneNumber,
      'Other_phone_number_1': otherPhoneNumber1,
      'Other_phone_number_2': otherPhoneNumber2,
      'Other_phone_number_3': otherPhoneNumber3,
      'Player_Category_Id': playerCategoryId,
      'NickName': nickName,
      'Flag': flag,
    };
  }

  factory Player.fromMap(Map<String, dynamic> map) {
    return Player(
      playerId: map['Player_Id'] as int?,
      playedSuperBowl: map['Played_Super_Bowl'] as int,
      name: map['Name'] as String,
      emailAddress: map['Email_address'] as String?,
      phoneNumber: map['Phone_number'] as String?,
      otherPhoneNumber1: map['Other_phone_number_1'] as String?,
      otherPhoneNumber2: map['Other_phone_number_2'] as String?,
      otherPhoneNumber3: map['Other_phone_number_3'] as String?,
      playerCategoryId: map['Player_Category_Id'] as int?,
      nickName: map['NickName'] as String?,
      flag: map['Flag'] as String?,
    );
  }

  @override
  String toString() {
    return 'Player(playerId: $playerId, playedSuperBowl: $playedSuperBowl, name: $name, emailAddress: $emailAddress, phoneNumber: $phoneNumber, otherPhoneNumber1: $otherPhoneNumber1, otherPhoneNumber2: $otherPhoneNumber2, otherPhoneNumber3: $otherPhoneNumber3, playerCategoryId: $playerCategoryId, nickName: $nickName, flag: $flag)';
  }
}
