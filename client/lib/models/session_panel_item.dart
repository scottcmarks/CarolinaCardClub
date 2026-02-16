// client/lib/models/session_panel_item.dart

class SessionPanelItem {
  final int sessionId;
  final int playerId;
  final String name;
  final DateTime startTime;
  final DateTime? stopTime;
  final double amount;
  final double balance;
  final double rate;

  // OPTIONAL FIELDS (Nullable)
  final int? pokerTableId;
  final int? seatNumber;

  final bool isPrepaid;
  final double prepayAmount;

  SessionPanelItem({
    required this.sessionId,
    required this.playerId,
    required this.name,
    required this.startTime,
    this.stopTime,
    required this.amount,
    required this.balance,
    required this.rate,
    this.pokerTableId,
    this.seatNumber,
    this.isPrepaid = false,
    this.prepayAmount = 0.0,
  });

  factory SessionPanelItem.fromMap(Map<String, dynamic> map) {
    return SessionPanelItem(
      sessionId: map['Session_Id'] as int,
      playerId: map['Player_Id'] as int,
      name: map['Name'] ?? 'Unknown', // Safety for Name
      startTime: DateTime.fromMillisecondsSinceEpoch((map['Start_Epoch'] as int) * 1000),
      stopTime: map['Stop_Epoch'] != null
          ? DateTime.fromMillisecondsSinceEpoch((map['Stop_Epoch'] as int) * 1000)
          : null,
      amount: (map['Amount'] as num? ?? 0.0).toDouble(), // Safe num cast
      balance: (map['Balance'] as num? ?? 0.0).toDouble(), // Safe num cast
      rate: (map['Rate'] as num? ?? 0.0).toDouble(),       // Safe num cast

      // *** THE CRITICAL FIXES ***
      // Safely handle NULLs for Table/Seat (common in old data)
      pokerTableId: map['PokerTable_Id'] as int?,
      seatNumber: map['Seat_Number'] as int?,

      // Safely handle NULLs for Prepay flags
      isPrepaid: (map['Is_Prepaid'] as int? ?? 0) == 1,
      prepayAmount: (map['Prepay_Amount'] as num? ?? 0.0).toDouble(),
    );
  }
}