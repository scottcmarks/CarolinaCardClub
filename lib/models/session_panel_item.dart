// models/session_panel_item.dart
class SessionPanelItem {
  final int sessionId;
  final int playerId;
  final String name;
  final int startEpoch;
  final int? stopEpoch; // Nullable as per schema
  final int durationInSeconds;
  final double amount;
  final double balance;

  SessionPanelItem({
    required this.sessionId,
    required this.playerId,
    required this.name,
    required this.startEpoch,
    this.stopEpoch, // Make optional
    required this.durationInSeconds,
    required this.amount,
    required this.balance,
  });

  // Convert a SessionPanelItem object into a Map.
  Map<String, dynamic> toMap() {
    return {
      'Session_Id': sessionId,
      'Player_Id': playerId,
      'Name': name,
      'StartEpoch': startEpoch,
      'Stop_Epoch': stopEpoch,
      'Duration_In_Seconds': durationInSeconds,
      'Amount': amount,
      'Balance': balance,
    };
  }

  // Create a SessionPanelItem object from a Map.
  factory SessionPanelItem.fromMap(Map<String, dynamic> map) {
    return SessionPanelItem(
      sessionId: map['Session_Id'],
      playerId: map['Player_Id'],
      name: map['Name'] ?? 'Unnamed', // Provide a default if name is null
      startEpoch: map['StartEpoch'],
      stopEpoch: map['Stop_Epoch'], // Will be null if it's not set in the DB
      durationInSeconds: map['Duration_In_Seconds'],
      amount: (map['Amount'] is int) ? (map['Amount'] as int).toDouble() : map['Amount'],
      balance: (map['Balance'] is int) ? (map['Balance'] as int).toDouble() : map['Balance'],
    );
  }
}
