// client/lib/widgets/real_time_clock.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/time_provider.dart';

class RealTimeClock extends StatelessWidget {
  const RealTimeClock({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TimeProvider>(
      builder: (context, timeProvider, _) {
        final t = timeProvider.currentTime;
        final timeString = DateFormat('HH:mm:ss').format(t);
        final dateString = DateFormat('MM/dd/yy').format(t);
        final hasOffset = timeProvider.offset != Duration.zero;

        final fillColor = hasOffset
            ? Colors.orange.withValues(alpha: 0.25)
            : Colors.white.withValues(alpha: 0.15);
        final borderColor = hasOffset
            ? Colors.orange.withValues(alpha: 0.6)
            : Colors.white.withValues(alpha: 0.30);
        const textColor = Colors.white;
        const dimColor = Color(0x80FFFFFF);

        return ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              decoration: BoxDecoration(
                color: fillColor,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dateString,
                    style: const TextStyle(
                      color: textColor,
                      fontSize: 13,
                      letterSpacing: 1,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('|', style: TextStyle(color: dimColor, fontSize: 15)),
                  ),
                  Text(
                    timeString,
                    style: const TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
