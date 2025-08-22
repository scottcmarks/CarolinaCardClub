// lib/session_panel.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// Import your custom files
import 'app_settings_provider.dart';
import 'app_settings.dart';
import 'database_provider.dart';
import 'models/session_panel_item.dart'; // Your SessionPanelItem model

class SessionPanel extends StatelessWidget {
  final ValueChanged<int?>? onSessionSelected; // Callback for when a session is tapped
  final void Function()? onOpenSettings; // Callback for when Settings bottom sheet requested by icon
  final int? selectedPlayerId;
  final int? selectedSessionId;

  const SessionPanel({
    super.key,
    this.onSessionSelected,
    this.onOpenSettings,
    this.selectedPlayerId,
    this.selectedSessionId,
  });

  @override
  Widget build(BuildContext context) {
    final AppSettingsProvider? _appSettingsProvider = Provider.of<AppSettingsProvider>(context);
    final AppSettings? _currentSettings = _appSettingsProvider!.currentSettings;
    final bool _showOnlyActiveSessions = _currentSettings!.showOnlyActiveSessions;
    final TimeOfDay? _defaultStartTime = _currentSettings!.defaultStartTime;

    // Listen to DatabaseProvider for its loading status and database instance
    return Consumer<DatabaseProvider>(
      builder: (context, databaseProvider, child) {
        // Handle different loading states of the database itself
        switch (databaseProvider.loadStatus) {
          case DatabaseLoadStatus.initial:
          case DatabaseLoadStatus.loadingRemote:
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text('Downloading database...'), // More specific message
                ],
              ),
            );
          case DatabaseLoadStatus.loadingAssets:
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text('Loading database from assets...'), // Informing about fallback
                ],
              ),
            );
          case DatabaseLoadStatus.error:
            // The database itself failed to load
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Failed to load database. Please check settings and internet connection.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red),
                ),
              ),
            );
          case DatabaseLoadStatus.loaded:
            // Database is loaded, now load panel-specific data using a FutureBuilder
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                ),
                Row(
                  children: [
                    Text(
                      _defaultStartTime==null
                        ? 'null'
                        : 'Start Time: ${_defaultStartTime!.hour}:${_defaultStartTime!.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                    ),
                    Spacer(),
                    Text(
                      _showOnlyActiveSessions ? 'Active' : 'All',
                      style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                    ),
                    IconButton( // <--- Settings Icon Button
                      icon: const Icon(Icons.settings),
                      tooltip: 'Open Settings',
                      onPressed: onOpenSettings, // <--- Call the passed callback
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: FutureBuilder<List<SessionPanelItem>>(
                    future: databaseProvider.fetchSessionPanelList(
                      showOnlyActiveSessions:_showOnlyActiveSessions,
                      playerId:selectedPlayerId,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        // This error is from fetching sessions, not the database itself loading
                        return Center(child: Text('Error loading sessions: ${snapshot.error}'));
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(child: Text('No ${_showOnlyActiveSessions ? 'active sessions' : 'sessions'} found.'));
                      } else {
                        List<SessionPanelItem> sessions = snapshot.data!;
                        return ListView.builder(
                          key: const PageStorageKey<String>('SessionListScrollPosition'),
                          itemCount: sessions.length,
                          itemBuilder: (context, index) {
                            final session = sessions[index];
                            final int sessionId = session.sessionId;
                            final bool isSelected = sessionId == selectedSessionId;

                            // Determine background color
                            Color? cardColor = isSelected ? Colors.blue.shade100 : null;

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                              color: cardColor,
                              child: MouseRegion(
                                onHover: (PointerHoverEvent event) {
                                  // You might want to add hover logic here as well
                                },
                                child: InkWell(
                                  onTap: () {
                                    onSessionSelected?.call(sessionId);
                                  },
                                  child: ListTile(
                                    title: Text('sessionId: ${session.sessionId}   ${session.name}   ${session.balance}'),
                                    subtitle: Text('${session.amount}  ${session.durationInSeconds}   ${session.startEpoch} - ${session.stopEpoch}'), // Example
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      }
                    },
                  ),
                ),
              ]
            );
        };
      },
    );
  }
}
