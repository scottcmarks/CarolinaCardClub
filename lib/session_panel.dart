// session_panel.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Import your custom files
import 'database/database_provider.dart'; // Your DatabaseProvider (ChangeNotifier)
import 'models/session_panel_item.dart'; // Your SessionPanelItem model

class SessionPanel extends StatelessWidget {
  final bool showOnlyActiveSessions;
  final int? playerId;

  const SessionPanel({
    super.key,
    required this.showOnlyActiveSessions,
    this.playerId,
  });

  Future<List<String>> _getFilteredSessionStrings(BuildContext context) async {
    // Access the DatabaseProvider provider
    final databaseProvider = Provider.of<DatabaseProvider>(context, listen: false);

    // Fetch the list of SessionPanelItem objects from the database
    List<SessionPanelItem> sessionItemList = await databaseProvider.fetchSessionPanelList(
      showingOnlyActiveSessions:showOnlyActiveSessions,
      playerId:playerId,
    );

    // Filter the list if necessary (though fetchSessionPanelList should handle it)
    // If fetchSessionPanelList returns all sessions and you need to filter further:
    // if (showOnlyActiveSessions) {
    //   sessionItemList = sessionItemList.where((session) => session.isActive).toList();
    // }

    // Transform the list of SessionPanelItem into a List<String>
    // each showing the session number and player name.
    List<String> sessionStrings = sessionItemList.map((session) {
      return 'Session ${session.sessionId} - ${session.name}';
    }).toList(); // Important: Convert the Iterable returned by map to a List

    return sessionStrings;
  }

  @override
  Widget build(BuildContext context) {
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
          child: FutureBuilder<List<String>>(
            future: _getFilteredSessionStrings(context), // Call the async method
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                // While data is being fetched, show a loading indicator
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                // If an error occurred during data fetching
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                // If no data was found or the list is empty
                return const Center(child: Text('No sessions found.'));
              } else {
                // Data has been successfully fetched, display the list
                List<String> sessions = snapshot.data!;
                return ListView.builder(
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: const Icon(Icons.meeting_room),
                      title: Text(sessions[index]),
                      onTap: () {
                        // Handle tapping on a session item
                        print('Tapped on ${sessions[index]}');
                      },
                    );
                  },
                );
              }
            },
          ),
        ),
      ],
    );
  }
}
