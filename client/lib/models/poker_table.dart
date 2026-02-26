// client/lib/models/poker_table.dart

class PokerTable {
  final int pokerTableId;
  final String tableName;
  final int capacity;
  final bool isActive;

  PokerTable({
    required this.pokerTableId,
    required this.tableName,
    required this.capacity,
    required this.isActive,
  });

  String get name => tableName;

  factory PokerTable.fromJson(Map<String, dynamic> json) {
    return PokerTable(
      pokerTableId: (json['pokerTableId'] ?? json['PokerTable_Id']) as int,
      tableName: (json['tableName'] ?? json['Name'] ?? json['name'] ?? 'Table ${json['PokerTable_Id'] ?? json['pokerTableId']}') as String,
      capacity: (json['capacity'] ?? json['Capacity'] ?? 9) as int,
      isActive: json['isActive'] ?? (json['IsActive'] == 1), // Schema uses IsActive without underscore
    );
  }

  Map<String, dynamic> toJson() => {
    'pokerTableId': pokerTableId,
    'tableName': tableName,
    'capacity': capacity,
    'isActive': isActive,
  };
}