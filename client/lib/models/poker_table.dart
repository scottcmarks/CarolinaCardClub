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
    this.isActive = true,
  });

  factory PokerTable.fromMap(Map<String, dynamic> map) {
    return PokerTable(
      pokerTableId: map['PokerTable_Id'],
      name: map['Name'],
      capacity: map['Capacity'],
      isActive: (map['IsActive'] as int? ?? 1) == 1,
    );
  }
}