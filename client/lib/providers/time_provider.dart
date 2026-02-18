// client/lib/providers/time_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';

class TimeProvider with ChangeNotifier {
  DateTime _realNow = DateTime.now();
  Duration _offset = Duration.zero;
  Timer? _timer;

  DateTime get currentTime => _realNow.add(_offset);
  Duration get offset => _offset;

  TimeProvider() {
    _startTimer();
  }

  void _startTimer() {
    _realNow = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _realNow = DateTime.now();
      notifyListeners();
    });
  }

  /// Sets the offset directly. Used for resetting to zero.
  void setOffset(Duration newOffset) {
    _offset = newOffset;
    notifyListeners();
  }

  /// Sets the clock to match a specific target time by calculating the offset.
  void syncToTime(TimeOfDay target) {
    final now = DateTime.now();
    final targetDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      target.hour,
      target.minute,
      now.second,
    );

    // Offset = Target Time - Real Time
    _offset = targetDateTime.difference(now);
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}