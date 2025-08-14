// lib/models/player.dart
class Player {
  final int playerId;
  final String name;
  final double balance;

  Player({required this.playerId, required this.name, required this.balance});

  factory Player.fromMap(Map<String, dynamic> map) {
    return Player(
      playerId: map['Player_Id'],
      name: map['Name'],
      balance: (map['Balance'] as num).toDouble(), // Ensure correct type casting
    );
  }
}
