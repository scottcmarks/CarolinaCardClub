// client/lib/widgets/real_time_clock.dart

import 'dart:ui'; // Required for FontFeature
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/time_provider.dart';

class RealTimeClock extends StatelessWidget {
  const RealTimeClock({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TimeProvider>(
      builder: (context, timeProvider, child) {
        final String formattedTime =
            DateFormat('HH:mm:ss').format(timeProvider.currentTime);
        return Center(
          child: Text(
            formattedTime,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.normal,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        );
      },
    );
  }
}