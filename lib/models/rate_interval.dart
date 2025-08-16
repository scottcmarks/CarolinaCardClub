class RateInterval {
  final int? rateIntervalId;
  final String start; // Consider converting to DateTime for Dart usage
  final String stop;  // Consider converting to DateTime for Dart usage
  final int rateId;
  final int startEpoch; // Storing as integer for SQLite, can convert to DateTime when needed
  final int stopEpoch;  // Storing as integer for SQLite, can convert to DateTime when needed

  RateInterval({
    this.rateIntervalId,
    required this.start,
    required this.stop,
    required this.rateId,
    this.startEpoch = 0,
    this.stopEpoch = 0,
  });

  RateInterval copyWith({
    int? rateIntervalId,
    String? start,
    String? stop,
    int? rateId,
    int? startEpoch,
    int? stopEpoch,
  }) {
    return RateInterval(
      rateIntervalId: rateIntervalId ?? this.rateIntervalId,
      start: start ?? this.start,
      stop: stop ?? this.stop,
      rateId: rateId ?? this.rateId,
      startEpoch: startEpoch ?? this.startEpoch,
      stopEpoch: stopEpoch ?? this.stopEpoch,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'Rate_Interval_Id': rateIntervalId,
      'Start': start,
      'Stop': stop,
      'Rate_Id': rateId,
      'Start_Epoch': startEpoch,
      'Stop_Epoch': stopEpoch,
    };
  }

  factory RateInterval.fromMap(Map<String, dynamic> map) {
    return RateInterval(
      rateIntervalId: map['Rate_Interval_Id'] as int?,
      start: map['Start'] as String,
      stop: map['Stop'] as String,
      rateId: map['Rate_Id'] as int,
      startEpoch: map['Start_Epoch'] as int,
      stopEpoch: map['Stop_Epoch'] as int,
    );
  }

  @override
  String toString() {
    return 'RateInterval(rateIntervalId: $rateIntervalId, start: $start, stop: $stop, rateId: $rateId, startEpoch: $startEpoch, stopEpoch: $stopEpoch)';
  }
}
