class Rate {
  final int? rateId;
  final double rate;
  final String? description;

  Rate({
    this.rateId,
    this.rate = 0.00,
    this.description,
  });

  Rate copyWith({
    int? rateId,
    double? rate,
    String? description,
  }) {
    return Rate(
      rateId: rateId ?? this.rateId,
      rate: rate ?? this.rate,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'Rate_Id': rateId,
      'Rate': rate,
      'Description': description,
    };
  }

  factory Rate.fromMap(Map<String, dynamic> map) {
    return Rate(
      rateId: map['Rate_Id'] as int?,
      rate: (map['Rate'] as num).toDouble(),
      description: map['Description'] as String?,
    );
  }

  @override
  String toString() {
    return 'Rate(rateId: $rateId, rate: $rate, description: $description)';
  }
}
