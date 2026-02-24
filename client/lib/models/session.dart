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
  final int prepayAmount; // Integer Dollars

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
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      sessionId: json['sessionId'] as int,
      playerId: json['playerId'] as int,
      name: json['name'] ?? "Unknown",
      pokerTableId: json['pokerTableId'] as int?,
      seatNumber: json['seatNumber'] as int?,
      startEpoch: json['startEpoch'] as int,
      stopTime: json['stopTime'] as int?,
      isPrepaid: json['isPrepaid'] ?? false,
      prepayAmount: (json['prepayAmount'] ?? 0).toInt(),
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
  };
}