class Payment {
  final int? paymentId;
  final int playerId;
  final double amount;
  final int
      epoch; // Storing as integer for SQLite, can convert to DateTime when needed

  Payment({
    this.paymentId,
    required this.playerId,
    required this.amount,
    required this.epoch,
  });

  Payment copyWith({
    int? paymentId,
    int? playerId,
    double? amount,
    int? epoch,
  }) {
    return Payment(
      paymentId: paymentId ?? this.paymentId,
      playerId: playerId ?? this.playerId,
      amount: amount ?? this.amount,
      epoch: epoch ?? this.epoch,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'Payment_Id': paymentId,
      'Player_Id': playerId,
      'Amount': amount,
      'Epoch': epoch,
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      paymentId: map['Payment_Id'] as int?,
      playerId: map['Player_Id'] as int,
      amount:
          (map['Amount'] as num).toDouble(), // SQLite stores NUMERIC as REAL
      epoch: map['Epoch'] as int,
    );
  }

  @override
  String toString() {
    return 'Payment(paymentId: $paymentId, playerId: $playerId, amount: $amount, epoch: $epoch)';
  }
}
