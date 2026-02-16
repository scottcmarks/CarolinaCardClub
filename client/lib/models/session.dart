// client/lib/models/session.dart

class Session {
  final int? sessionId;
  final int playerId;
  final int? startEpoch;
  final int? stopEpoch;
  final int pokerTableId;
  final int? seatNumber;
  final bool isPrepaid;
  final double prepayAmount;

  Session({
    this.sessionId,
    required this.playerId,
    this.startEpoch,
    this.stopEpoch,
    required this.pokerTableId,
    this.seatNumber,
    this.isPrepaid = false,
    this.prepayAmount = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'Session_Id': sessionId,
      'Player_Id': playerId,
      'Start_Epoch': startEpoch,
      'Stop_Epoch': stopEpoch,
      'PokerTable_Id': pokerTableId,
      'Seat_Number': seatNumber,
      'Is_Prepaid': isPrepaid ? 1 : 0,
      'Prepay_Amount': prepayAmount,
    };
  }
}