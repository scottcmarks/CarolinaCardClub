
// lib/models/session.dart
class Session {
  final int sessionId;
  final int playerId;
  // Add other fields from Session_Selection_List as needed

  Session({required this.sessionId, required this.playerId});

  factory Session.fromMap(Map<String, dynamic> map) {
    return Session(
      sessionId: map['Session_Id'],
      playerId: map['Player_Id'],
      // Map other fields
    );
  }
}
