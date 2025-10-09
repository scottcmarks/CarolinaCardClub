
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // For formatting the time
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart'; // Required for ChangeNotifier


class TimeProvider with ChangeNotifier {
  DateTime _currentTime = DateTime.now();
  Duration _offset = Duration();

// Getter to expose the current time
  DateTime get currentTime => _currentTime;

  // Getter to expose the offset
  Duration get offset => _offset;

  late Timer _timer;

  TimeProvider() {
    // Timer.periodic creates a repeating timer
    // It calls the callback function every duration interval
    _timer = Timer.periodic(const Duration(seconds: 1),
      (timer) { _updateAndNotify(); }
    );
  }

  void _updateAndNotify() {
    _currentTime = DateTime.now().add(_offset); // Update the current time
    notifyListeners(); // Notify all listening widgets about the change
  }

  // Method to allow external modification of the time (e.g., from settings)
  void setTime(DateTime newTime) {
    _offset = newTime.difference(DateTime.now());
    _updateAndNotify();
  }

  // Method to allow external modification of the offset (e.g., from settings)
  void setOffset(Duration newOffset) {
    _offset = newOffset;
    _updateAndNotify();
  }

  // Method to allow external reset of the offset (e.g., from settings)
  void reset() {
    _offset = Duration();
    _updateAndNotify();
  }

  // Important: Override dispose to cancel the timer when the provider is no longer needed
  @override
  void dispose() {
    _timer.cancel(); // Cancel the timer to prevent memory leaks
    super.dispose();
  }
}
