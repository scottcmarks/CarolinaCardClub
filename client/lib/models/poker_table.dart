// client/lib/models/poker_table.dart

class PokerTable {
  final int pokerTableId;
  final String name;
  final int capacity;
  final bool isActive;

  PokerTable({
    required this.pokerTableId,
    required this.name,
    required this.capacity,
    required this.isActive,
  });

  // Factory for parsing JSON from API
  factory PokerTable.fromMap(Map<String, dynamic> map) {
    return PokerTable(
      pokerTableId: map['Poker_Table_Id'] ?? 0,
      name: map['Name'] ?? 'Unknown',
      capacity: map['Capacity'] ?? 9,
      // Handle SQLite (1/0) or JSON (true/false) booleans
      isActive: map['Is_Active'] == 1 || map['Is_Active'] == true,
    );
  }

  // --- ADDED THIS METHOD ---
  PokerTable copyWith({
    int? pokerTableId,
    String? name,
    int? capacity,
    bool? isActive,
  }) {
    return PokerTable(
      pokerTableId: pokerTableId ?? this.pokerTableId,
      name: name ?? this.name,
      capacity: capacity ?? this.capacity,
      isActive: isActive ?? this.isActive,
    );
  }
}