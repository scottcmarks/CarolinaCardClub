
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // For formatting the time

class RealtimeClock extends StatefulWidget {
  @override
  _RealtimeClockState createState() => _RealtimeClockState();
}

class _RealtimeClockState extends State<RealtimeClock> {
  late DateTime _currentTime;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    // Update the time every second
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Format the time as desired
    String formattedTime = DateFormat('HH:mm:ss').format(_currentTime);

    return Text(
      formattedTime,
//      style: TextStyle(fontSize: 18, color: Colors.black), // Customize style as needed
      style: GoogleFonts.robotoMono(fontSize: 18, color: Colors.black), // Customize style as needed
    );
  }
}
