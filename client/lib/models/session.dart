// client/lib/models/session.dart

class Session {
  final int sessionId;
  final int playerId;
  final int? pokerTableId;
  final int? seatNumber;
  final int startEpoch;
  final bool isPrepaid;
  final double prepayAmount;

  Session({
    required this.sessionId,
    required this.playerId,
    this.pokerTableId,
    this.seatNumber,
    required this.startEpoch,
    required this.isPrepaid,
    required this.prepayAmount,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'Player_Id': playerId,
      'PokerTable_Id': pokerTableId,
      'Seat_Number': seatNumber,
      'Start_Epoch': startEpoch,
      'Is_Prepaid': isPrepaid ? 1 : 0,
      'Prepay_Amount': prepayAmount,
    };

    // Only include Session_Id if we are updating an existing record.
    // A value of 0 means it's a new record waiting for the DB to assign an ID.
    if (sessionId > 0) {
      map['Session_Id'] = sessionId;
    }

    return map;
  }

  factory Session.fromMap(Map<String, dynamic> map) {
    return Session(
      sessionId: map['Session_Id'] as int,
      playerId: map['Player_Id'] as int,
      pokerTableId: map['PokerTable_Id'] as int?,
      seatNumber: map['Seat_Number'] as int?,
      startEpoch: map['Start_Epoch'] as int,
      isPrepaid: (map['Is_Prepaid'] ?? 0) == 1,
      prepayAmount: (map['Prepay_Amount'] ?? 0).toDouble(),
    );
  }
}