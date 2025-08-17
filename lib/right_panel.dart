// right_panel.dart
import 'package:flutter/material.dart';
import 'session_panel.dart'; // Assume SessionPanel is in its own file

class RightPanel extends StatelessWidget {
  final bool showOnlyActiveSessions;

  const RightPanel({super.key, required this.showOnlyActiveSessions});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white, // Example background color
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Session Details',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Divider(),
          Expanded( // The SessionPanel will fill the remaining space
            child: SessionPanel(showOnlyActiveSessions: showOnlyActiveSessions),
          ),
        ],
      ),
    );
  }
}
