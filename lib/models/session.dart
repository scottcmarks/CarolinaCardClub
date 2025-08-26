// lib/models/session.dart

class Session {
  final int? sessionId;
  final int playerId;
  final int startEpoch;
  final int? stopEpoch;

  const Session({
    this.sessionId,
    required this.playerId,
    required this.startEpoch,
    this.stopEpoch,
  });

  /// Creates a Session instance from a database map.
  factory Session.fromMap(Map<String, dynamic> map) {
    return Session(
      sessionId: map['Session_Id'],
      playerId: map['Player_Id'],
      startEpoch: map['Start_Epoch'],
      stopEpoch: map['Stop_Epoch'],
    );
  }

  /// Converts this Session instance to a map for database insertion.
  Map<String, dynamic> toMap() {
    return {
      'Session_Id': sessionId,
      'Player_Id': playerId,
      'Start_Epoch': startEpoch,
      'Stop_Epoch': stopEpoch,
    };
  }
}
