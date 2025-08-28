
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // For formatting the time
import 'package:provider/provider.dart';

import '../providers/time_provider.dart';


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
