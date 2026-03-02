// client/lib/models/session.dart

class Session {
  final int sessionId;
  final int playerId;
  final String name;
  final int? pokerTableId;
  final int? seatNumber;
  final int startEpoch;
  final int? stopTime;
  final bool isPrepaid;
  final int prepayAmount;
  final double hourlyRate;

  Session({
    required this.sessionId,
    required this.playerId,
    this.name = "Unknown",
    this.pokerTableId,
    this.seatNumber,
    required this.startEpoch,
    this.stopTime,
    this.isPrepaid = false,
    this.prepayAmount = 0,
    this.hourlyRate = 0.0,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      sessionId: (json['sessionId'] ?? json['Session_Id']) as int,
      playerId: (json['playerId'] ?? json['Player_Id']) as int,
      name: (json['name'] ?? json['Name'] ?? "Unknown") as String,
      pokerTableId: (json['pokerTableId'] ?? json['PokerTable_Id']) as int?,
      seatNumber: (json['seatNumber'] ?? json['Seat_Number']) as int?,
      startEpoch: (json['startEpoch'] ?? json['Start_Epoch']) as int,
      stopTime: (json['stopTime'] ?? json['Stop_Epoch']) as int?,
      isPrepaid: json['isPrepaid'] ?? (json['Is_Prepaid'] == 1),
      prepayAmount: ((json['prepayAmount'] ?? json['Prepay_Amount'] ?? 0) as num).toInt(),
      hourlyRate: ((json['hourlyRate'] ?? json['Hourly_Rate'] ?? json['Rate'] ?? 0.0) as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'playerId': playerId,
    'pokerTableId': pokerTableId,
    'seatNumber': seatNumber,
    'startEpoch': startEpoch,
    'isPrepaid': isPrepaid,
    'prepayAmount': prepayAmount,
    'hourlyRate': hourlyRate,
  };
}