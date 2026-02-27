// client/lib/providers/time_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';

class TimeProvider with ChangeNotifier {
  DateTime _realTime = DateTime.now();
  Duration _offset = Duration.zero;
  Timer? _timer;

  TimeProvider() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _realTime = DateTime.now();
      notifyListeners();
    });
  }

  // The actual real-world time
  DateTime get realTime => _realTime;

  // The active time offset for debugging/simulating
  Duration get offset => _offset;

  // The possibly offset time
  DateTime get currentTime => _realTime.add(_offset);

  // The possibly offset time formatted as an epoch integer number of seconds
  int get nowEpoch => (currentTime.millisecondsSinceEpoch / 1000).round();

  void setOffset(Duration newOffset) {
    _offset = newOffset;
    notifyListeners();
  }

  void addOffset(Duration additionalOffset) {
    _offset += additionalOffset;
    notifyListeners();
  }

  void resetOffset() {
    _offset = Duration.zero;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}