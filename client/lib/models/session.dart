// client/lib/models/session.dart

class Session {
  final int? sessionId;
  final int playerId;
  final int startEpoch; // REQUIRED: Cannot be null
  final int? stopEpoch;
  final int pokerTableId;
  final int? seatNumber;
  final bool isPrepaid;
  final double prepayAmount;
  final double rate; // Optional for creation, but useful if model is reused

  Session({
    this.sessionId,
    required this.playerId,
    required this.startEpoch,
    this.stopEpoch,
    required this.pokerTableId,
    this.seatNumber,
    this.isPrepaid = false,
    this.prepayAmount = 0.0,
    this.rate = 0.0,
  });

  // Convert to Map for JSON encoding (Sent to Server)
  Map<String, dynamic> toMap() {
    return {
      if (sessionId != null) 'Session_Id': sessionId,
      'Player_Id': playerId,
      'Start_Epoch': startEpoch, // This was likely missing or null before!
      'Stop_Epoch': stopEpoch,
      'PokerTable_Id': pokerTableId,
      'Seat_Number': seatNumber,
      'Is_Prepaid': isPrepaid ? 1 : 0,
      'Prepay_Amount': prepayAmount,
    };
  }

  // Create from Map (Received from Server/DB)
  factory Session.fromMap(Map<String, dynamic> map) {
    return Session(
      sessionId: map['Session_Id'],
      playerId: map['Player_Id'] ?? 0,
      startEpoch: map['Start_Epoch'] ?? 0,
      stopEpoch: map['Stop_Epoch'],
      pokerTableId: map['PokerTable_Id'] ?? -1,
      seatNumber: map['Seat_Number'],
      isPrepaid: (map['Is_Prepaid'] == 1 || map['Is_Prepaid'] == true),
      prepayAmount: (map['Prepay_Amount'] ?? 0.0).toDouble(),
      rate: (map['Rate'] ?? 0.0).toDouble(),
    );
  }
}