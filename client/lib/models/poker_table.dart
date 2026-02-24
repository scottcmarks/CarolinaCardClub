// client/lib/models/poker_table.dart

class PokerTable {
  final int pokerTableId;
  final String tableName;
  final int capacity;
  final bool isActive; // Restored

  PokerTable({
    required this.pokerTableId,
    required this.tableName,
    required this.capacity,
    required this.isActive,
  });

  String get name => tableName;

  factory PokerTable.fromJson(Map<String, dynamic> json) {
    return PokerTable(
      pokerTableId: json['pokerTableId'] as int,
      tableName: (json['tableName'] ?? json['name'] ?? 'Table ${json['pokerTableId']}') as String,
      capacity: json['capacity'] as int,
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'pokerTableId': pokerTableId,
    'tableName': tableName,
    'capacity': capacity,
    'isActive': isActive,
  };
}