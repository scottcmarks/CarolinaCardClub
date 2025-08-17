
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // For formatting the time
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart'; // Required for ChangeNotifier


class TimeProvider with ChangeNotifier {
  DateTime _currentTime = DateTime.now();
  Duration _offset = Duration();
  late Timer _timer;

  // Getter to expose the current time
  DateTime get currentTime => _currentTime;

  TimeProvider() {
    _startTimer();
  }

  void _updateAndNotify() {
    _currentTime = DateTime.now().add(_offset); // Update the current time
    notifyListeners(); // Notify all listening widgets about the change
  }

  void _startTimer() {
    // Timer.periodic creates a repeating timer
    // It calls the callback function every duration interval
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateAndNotify();
    });
  }

  // Method to allow external modification of the time (e.g., from settings)
  void userSetClock(DateTime newTime) {
    _offset = newTime.difference(DateTime.now());
    _updateAndNotify();
  }

  // Important: Override dispose to cancel the timer when the provider is no longer needed
  @override
  void dispose() {
    _timer.cancel(); // Cancel the timer to prevent memory leaks
    super.dispose();
  }
}


class RealtimeClock extends StatelessWidget {
  const RealtimeClock({super.key});

  @override
  Widget build(BuildContext context) {
    // Access the TimeProvider.
    // By default, listen: true, so this widget will rebuild every second
    final timeProvider = Provider.of<TimeProvider>(context);

    // Get the current time from the provider
    DateTime currentTime = timeProvider.currentTime;

    String formattedTime = DateFormat('HH:mm:ss').format(currentTime);

    return Text(
      formattedTime,
      style: GoogleFonts.robotoMono(fontSize: 18, color: Colors.black), // Customize style as needed
    );
  }
}
