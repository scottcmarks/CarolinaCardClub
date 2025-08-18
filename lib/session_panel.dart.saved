// session_panel.dart
import 'package:flutter/material.dart';

class SessionPanel extends StatelessWidget {
  final bool showOnlyActiveSessions;

  const SessionPanel({
    super.key,
    required this.showOnlyActiveSessions,
  });

  // Example method to fetch/filter sessions based on the flag
  List<String> _getSessions(bool showActive) {
    // In a real app, this would likely interact with a DatabaseHelper
    // or a state management solution (like Provider, BLoC, etc.)
    // to fetch the actual session data.

    if (showActive) {
      return ['Active Session 1', 'Active Session 2', 'Active Session 3'];
    } else {
      return [
        'Active Session 1',
        'Inactive Session A',
        'Active Session 2',
        'Inactive Session B',
        'Active Session 3',
        'Inactive Session C',
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> sessions = _getSessions(showOnlyActiveSessions);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            showOnlyActiveSessions ? 'Showing Active Sessions' : 'Showing All Sessions',
            style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView.builder(
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              return ListTile(
                leading: Icon(Icons.meeting_room),
                title: Text(sessions[index]),
                subtitle: Text('Details for ${sessions[index]}'),
                onTap: () {
                  // Handle tapping on a session item
                  print('Tapped on ${sessions[index]}');
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
