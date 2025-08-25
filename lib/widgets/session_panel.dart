// lib/widgets/session_panel.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/app_settings_provider.dart';
import '../providers/database_provider.dart';
import '../providers/time_provider.dart';

import '../models/app_settings.dart';
import '../models/session_panel_item.dart'; // Your SessionPanelItem model

class SessionPanel extends StatefulWidget {
  final ValueChanged<int?>? onSessionSelected; // Callback for when a session is tapped
  final int? selectedPlayerId;
  final int? selectedSessionId;

  const SessionPanel({
    super.key,
    this.onSessionSelected,
    this.selectedPlayerId,
    this.selectedSessionId,
  });

  @override
  _SessionPanelState createState() => _SessionPanelState();
}

DateTime epochToDateTime(int seconds) {
  return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
}

String formatEpoch(String format, int seconds) {
  return DateFormat(format).format(epochToDateTime(seconds));
}

String isoFormatEpoch(int seconds) {
  return formatEpoch('yy-MM-dd HH:mm', seconds);
}

String maybe_isoFormatEpoch(int? seconds, String ifNull) {
  return seconds != null ? isoFormatEpoch(seconds!) : ifNull;
}

String formatMoney(double price) {
  return '\$${price.toStringAsFixed(2)}';
}

String formatDuration(int totalSeconds) {
  final int totalMinutes = totalSeconds ~/ 60;

  final int hours = totalMinutes ~/ 60;
  final int minutes = totalMinutes.remainder(60);

  // Use padLeft for leading zeros and create the final string
  final String formattedHours = hours.toString();
  final String formattedMinutes = minutes.toString().padLeft(2, '0');

  return '${formattedHours}h${formattedMinutes}m';
}

class _SessionPanelState extends State<SessionPanel> {
  DateTime? _clubSessionStartDateTime = null;

  late AppSettingsProvider? _appSettingsProvider;

  void _toggleClubSessionTime(DateTime defaultTime) {
    setState(() {
      if (_clubSessionStartDateTime == null) {
        _clubSessionStartDateTime = defaultTime;
      } else {
        _clubSessionStartDateTime = null;
      }
      _appSettingsProvider!.setShowOnlyActiveSessions(_clubSessionStartDateTime != null);
    });
  }

  @override
  Widget build(BuildContext context) {
    _appSettingsProvider = Provider.of<AppSettingsProvider>(context);
    final AppSettings? _currentSettings = _appSettingsProvider!.currentSettings;
    final bool _showOnlyActiveSessions = _currentSettings!.showOnlyActiveSessions;
    final TimeOfDay? _defaultSessionStartTime = _currentSettings!.defaultSessionStartTime;
    final TimeProvider? _timeProvider = Provider.of<TimeProvider>(context, listen: false);
    final DateTime _now = _timeProvider!.currentTime;
    final DateTime _defaultSessionStartDateTime = DateTime(
      _now.year,
      _now.month,
      _now.day,
      _defaultSessionStartTime?.hour ?? 19,
      _defaultSessionStartTime?.minute ?? 30,
    );

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
                    const SizedBox(width: 16.0), // Adds a fixed 16-pixel space
                    InkWell(
                      onTap: () => _toggleClubSessionTime(_defaultSessionStartDateTime),
                      child: Text(
                        (_clubSessionStartDateTime != null)
                            ? 'Club session started at ${DateFormat("yyyy-MM-dd HH:mm").format(_clubSessionStartDateTime!)}'
                            : 'Club session would be started at ${DateFormat("yyyy-MM-dd HH:mm").format(_defaultSessionStartDateTime)}',
                        style: TextStyle(fontSize: 16, fontStyle: _clubSessionStartDateTime != null ? FontStyle.normal : FontStyle.italic),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _showOnlyActiveSessions ? 'Active' : 'All',
                      style: TextStyle(fontSize: 16, fontStyle: _clubSessionStartDateTime != null ? FontStyle.normal : FontStyle.italic),
                    ),
                    const SizedBox(width: 16.0), // Adds a fixed 16-pixel space
                  ],
                ),
                const Divider(),
                Expanded(
                  child: FutureBuilder<List<SessionPanelItem>>(
                    future: databaseProvider.fetchSessionPanelList(
                      showOnlyActiveSessions: _showOnlyActiveSessions,
                      playerId: widget.selectedPlayerId,
                    ),
                    builder: (context, snapshot) {
                      // TODO: factor out
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        // This error is from fetching sessions, not the database itself loading
                        return Center(child: Text('Error loading sessions: ${snapshot.error}'));
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(
                            child: Text(
                                'No ${_showOnlyActiveSessions ? 'active sessions' : 'sessions'} found.'));
                      } else {
                        List<SessionPanelItem> sessions = snapshot.data!;
                        return ListView.builder(
                          key: const PageStorageKey<String>('SessionListScrollPosition'),
                          itemCount: sessions.length,
                          itemBuilder: (context, index) {
                            final session = sessions[index];
                            final int sessionId = session.sessionId;
                            final bool isSelected = sessionId == widget.selectedSessionId;

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
                                    widget.onSessionSelected?.call(sessionId);
                                  },
                                  child: ListTile(
                                    title: Text(
                                        ' ${session.name}',
                                    ),
                                    subtitle: Text(
                                        'Player session ${session.sessionId}:'
                                        + '  ' +
                                        '${isoFormatEpoch(session.startEpoch)} - ${maybe_isoFormatEpoch(session.stopEpoch, "ongoing")}'
                                        + '  ' +
                                        '${formatDuration(session.durationInSeconds)}'
                                        + '  ' +
                                        '${formatMoney(session.amount)}'
                                        ,
                                    ),
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
              ],
            );
        }
      },
    );
  }
}
