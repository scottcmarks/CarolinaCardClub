// client/lib/models/session.dart

class Session {
  final int sessionId;
  final int playerId;
  final String? playerName;
  final int? pokerTableId;
  final int? seatNumber;
  final int startEpoch;
  final int? stopEpoch;
  final bool isPrepaid;
  final double prepayAmount;

  Session({
    required this.sessionId,
    required this.playerId,
    this.playerName,
    this.pokerTableId,
    this.seatNumber,
    required this.startEpoch,
    this.stopEpoch,
    required this.isPrepaid,
    required this.prepayAmount,
  });

  // --- UI Getters ---
  String get name => playerName ?? 'Unknown';

  DateTime? get stopTime => stopEpoch != null
      ? DateTime.fromMillisecondsSinceEpoch(stopEpoch! * 1000)
      : null;

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'Player_Id': playerId,
      'PokerTable_Id': pokerTableId,
      'Seat_Number': seatNumber,
      'Start_Epoch': startEpoch,
      'Stop_Epoch': stopEpoch,
      'Is_Prepaid': isPrepaid ? 1 : 0,
      'Prepay_Amount': prepayAmount,
    };
    if (sessionId > 0) map['Session_Id'] = sessionId;
    return map;
  }

  factory Session.fromMap(Map<String, dynamic> map) {
    return Session(
      sessionId: map['Session_Id'] as int? ?? 0,
      playerId: map['Player_Id'] as int? ?? 0,
      playerName: map['Player_Name'] as String?,
      pokerTableId: map['PokerTable_Id'] as int?,
      seatNumber: map['Seat_Number'] as int?,
      startEpoch: map['Start_Epoch'] as int? ?? 0,
      stopEpoch: map['Stop_Epoch'] as int?,
      isPrepaid: (map['Is_Prepaid'] == 1 || map['Is_Prepaid'] == true),
      prepayAmount: (map['Prepay_Amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}