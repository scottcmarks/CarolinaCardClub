// client/lib/models/rate_interval.dart

class RateInterval {
  final int? rateIntervalId;
  final int rateId;
  final int startEpoch;
  final int stopEpoch;

  RateInterval({
    this.rateIntervalId,
    required this.rateId,
    required this.startEpoch,
    required this.stopEpoch,
  });

  Map<String, dynamic> toMap() {
    return {
      'Rate_Interval_Id': rateIntervalId,
      'Rate_Id': rateId,
      'Start_Epoch': startEpoch,
      'Stop_Epoch': stopEpoch,
    };
  }

  factory RateInterval.fromMap(Map<String, dynamic> map) {
    return RateInterval(
      rateIntervalId: map['Rate_Interval_Id'] as int?,
      rateId: map['Rate_Id'] as int,
      startEpoch: map['Start_Epoch'] as int,
      stopEpoch: map['Stop_Epoch'] as int,
    );
  }

  @override
  String toString() {
    return 'RateInterval(rateIntervalId: $rateIntervalId, rateId: $rateId, startEpoch: $startEpoch, stopEpoch: $stopEpoch)';
  }
}