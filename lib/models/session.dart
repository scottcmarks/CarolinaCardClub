class Session {
  final int? sessionId;
  final int playerId;
  final int startEpoch; // Storing as integer for SQLite, can convert to DateTime when needed
  final int? stopEpoch; // Storing as integer for SQLite, can convert to DateTime when needed

  Session({
    this.sessionId,
    required this.playerId,
    this.startEpoch = 0,
    this.stopEpoch,
  });

  Session copyWith({
    int? sessionId,
    int? playerId,
    int? startEpoch,
    int? stopEpoch,
  }) {
    return Session(
      sessionId: sessionId ?? this.sessionId,
      playerId: playerId ?? this.playerId,
      startEpoch: startEpoch ?? this.startEpoch,
      stopEpoch: stopEpoch ?? this.stopEpoch,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'Session_Id': sessionId,
      'Player_Id': playerId,
      'Start_Epoch': startEpoch,
      'Stop_Epoch': stopEpoch,
    };
  }

  factory Session.fromMap(Map<String, dynamic> map) {
    return Session(
      sessionId: map['Session_Id'] as int?,
      playerId: map['Player_Id'] as int,
      startEpoch: map['Start_Epoch'] as int,
      stopEpoch: map['Stop_Epoch'] as int?,
    );
  }

  @override
  String toString() {
    return 'Session(sessionId: $sessionId, playerId: $playerId, startEpoch: $startEpoch, stopEpoch: $stopEpoch)';
  }
}
