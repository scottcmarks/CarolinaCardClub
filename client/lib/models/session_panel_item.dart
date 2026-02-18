// client/lib/models/session_panel_item.dart

class SessionPanelItem {
  final int sessionId;
  final int playerId;
  final String name;
  final DateTime startTime;
  final DateTime? stopTime;

  // CHANGED: Now nullable to support legacy records
  final int? pokerTableId;
  final int? seatNumber;

  final bool isPrepaid;
  final int prepayAmount;
  final int balance;
  final double rate;
  final int? amount;

  SessionPanelItem({
    required this.sessionId,
    required this.playerId,
    required this.name,
    required this.startTime,
    this.stopTime,
    this.pokerTableId, // Optional/Nullable
    this.seatNumber,   // Optional/Nullable
    required this.isPrepaid,
    required this.prepayAmount,
    required this.balance,
    required this.rate,
    this.amount,
  });

  factory SessionPanelItem.fromMap(Map<String, dynamic> map) {
    return SessionPanelItem(
      sessionId: map['Session_Id'] as int,
      playerId: map['Player_Id'] as int,
      name: map['Name'] as String,
      startTime: DateTime.fromMillisecondsSinceEpoch((map['Start_Epoch'] as int) * 1000),
      stopTime: map['Stop_Epoch'] != null
          ? DateTime.fromMillisecondsSinceEpoch((map['Stop_Epoch'] as int) * 1000)
          : null,

      // FIX: Cast as nullable int to allow legacy NULLs without crashing
      pokerTableId: map['PokerTable_Id'] as int?,
      seatNumber: map['Seat_Number'] as int?,

      isPrepaid: (map['Is_Prepaid'] ?? 0) == 1,
      // Default to 0 for math safety (prevent "Null is not subtype of int")
      prepayAmount: (map['Prepay_Amount'] ?? 0) as int,
      balance: (map['Balance'] ?? 0) as int,
      rate: (map['Rate'] ?? 0).toDouble(),
      amount: map['Amount'] != null ? (map['Amount'] as int) : null,
    );
  }
}