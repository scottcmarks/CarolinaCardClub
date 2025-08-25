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
import '../models/session_panel_item.dart';

class SessionPanel extends StatefulWidget {
  final ValueChanged<int?>? onSessionSelected;
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

// Helper Functions
DateTime epochToDateTime(int seconds) {
  return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
}

String formatEpoch(String format, int seconds) {
  return DateFormat(format).format(epochToDateTime(seconds));
}

String isoFormatEpoch(int seconds) {
  return formatEpoch('yyyy-MM-dd HH:mm', seconds);
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
  final String formattedHours = hours.toString();
  final String formattedMinutes = minutes.toString().padLeft(2, '0');
  return '${formattedHours}h${formattedMinutes}m';
}

class _SessionPanelState extends State<SessionPanel> {
  DateTime? _clubSessionStartDateTime;

  void _toggleClubSessionTime(DateTime defaultTime, AppSettingsProvider appSettingsProvider) {
    setState(() {
      if (_clubSessionStartDateTime == null) {
        _clubSessionStartDateTime = defaultTime;
      } else {
        _clubSessionStartDateTime = null;
      }
      appSettingsProvider.setShowOnlyActiveSessions(_clubSessionStartDateTime != null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppSettingsProvider>(
      builder: (context, appSettingsProvider, child) {
        final AppSettings? _currentSettings = appSettingsProvider.currentSettings;
        final bool _showOnlyActiveSessions = _currentSettings!.showOnlyActiveSessions;
        final TimeOfDay? _defaultSessionStartTime = _currentSettings.defaultSessionStartTime;
        final TimeProvider? _timeProvider = Provider.of<TimeProvider>(context, listen: false);
        final DateTime _now = _timeProvider!.currentTime;
        final DateTime _defaultSessionStartDateTime = DateTime(
          _now.year,
          _now.month,
          _now.day,
          _defaultSessionStartTime?.hour ?? 19,
          _defaultSessionStartTime?.minute ?? 30,
        );

        return Consumer<DatabaseProvider>(
          builder: (context, databaseProvider, child) {
            switch (databaseProvider.loadStatus) {
              case DatabaseLoadStatus.initial:
              case DatabaseLoadStatus.loadingRemote:
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 10),
                      Text('Downloading database...'),
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
                      Text('Loading database from assets...'),
                    ],
                  ),
                );
              case DatabaseLoadStatus.error:
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
                return Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                    ),
                    SessionPanelHeader(
                      clubSessionStartDateTime: _clubSessionStartDateTime,
                      defaultSessionStartDateTime: _defaultSessionStartDateTime,
                      showOnlyActiveSessions: _showOnlyActiveSessions,
                      onTap: () => _toggleClubSessionTime(_defaultSessionStartDateTime, appSettingsProvider),
                    ),
                    const Divider(),
                    Expanded(
                      child: SessionPanelBody(
                        databaseProvider: databaseProvider,
                        showOnlyActiveSessions: _showOnlyActiveSessions,
                        selectedPlayerId: widget.selectedPlayerId,
                        selectedSessionId: widget.selectedSessionId,
                        onSessionSelected: widget.onSessionSelected,
                      ),
                    ),
                  ],
                );
            }
          },
        );
      },
    );
  }
}

/// Displays the header for the session panel, including the club session time
/// and the current filter status ('Active' or 'All').
class SessionPanelHeader extends StatelessWidget {
  final DateTime? clubSessionStartDateTime;
  final DateTime defaultSessionStartDateTime;
  final bool showOnlyActiveSessions;
  final VoidCallback onTap;

  const SessionPanelHeader({
    super.key,
    required this.clubSessionStartDateTime,
    required this.defaultSessionStartDateTime,
    required this.showOnlyActiveSessions,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 16.0),
        InkWell(
          onTap: onTap,
          child: Text(
            (clubSessionStartDateTime != null)
                ? 'Club session started at ${DateFormat("yyyy-MM-dd HH:mm").format(clubSessionStartDateTime!)}'
                : 'Club session would be started at ${DateFormat("yyyy-MM-dd HH:mm").format(defaultSessionStartDateTime)}',
            style: TextStyle(
                fontSize: 16, fontStyle: clubSessionStartDateTime != null ? FontStyle.normal : FontStyle.italic),
          ),
        ),
        const Spacer(),
        Text(
          showOnlyActiveSessions ? 'Active' : 'All',
          style: TextStyle(
              fontSize: 16, fontStyle: clubSessionStartDateTime != null ? FontStyle.normal : FontStyle.italic),
        ),
        const SizedBox(width: 16.0),
      ],
    );
  }
}

/// Displays the body of the session panel, which is a list of sessions fetched
/// from the database.
class SessionPanelBody extends StatelessWidget {
  final DatabaseProvider databaseProvider;
  final bool showOnlyActiveSessions;
  final int? selectedPlayerId;
  final int? selectedSessionId;
  final ValueChanged<int?>? onSessionSelected;

  const SessionPanelBody({
    super.key,
    required this.databaseProvider,
    required this.showOnlyActiveSessions,
    this.selectedPlayerId,
    this.selectedSessionId,
    this.onSessionSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SessionPanelItem>>(
      future: databaseProvider.fetchSessionPanelList(
        showOnlyActiveSessions: showOnlyActiveSessions,
        playerId: selectedPlayerId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error loading sessions: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('No ${showOnlyActiveSessions ? 'active sessions' : 'sessions'} found.'));
        } else {
          List<SessionPanelItem> sessions = snapshot.data!;
          return ListView.builder(
            key: const PageStorageKey<String>('SessionListScrollPosition'),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              final bool isSelected = session.sessionId == selectedSessionId;

              // Use a conditional to choose which card to display
              if (selectedPlayerId != null) {
                return SelectedPlayerCard(
                  session: session,
                  isSelected: isSelected,
                  onSessionSelected: onSessionSelected,
                );
              } else {
                return AllPlayersCard(
                  session: session,
                  isSelected: isSelected,
                  onSessionSelected: onSessionSelected,
                );
              }
            },
          );
        }
      },
    );
  }
}

/// A card to display session information for a specific, selected player.
class SelectedPlayerCard extends StatelessWidget {
  final SessionPanelItem session;
  final bool isSelected;
  final ValueChanged<int?>? onSessionSelected;

  const SelectedPlayerCard({
    super.key,
    required this.session,
    required this.isSelected,
    this.onSessionSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      color: isSelected ? Colors.blue.shade100 : null,
      child: MouseRegion(
        onHover: (PointerHoverEvent event) {},
        child: InkWell(
          onTap: () {
            onSessionSelected?.call(session.sessionId);
          },
          child: ListTile(
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    '${isoFormatEpoch(session.startEpoch)} - ${maybe_isoFormatEpoch(session.stopEpoch, "ongoing")}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  'Session: ${session.sessionId}',
                  style: Theme.of(context).textTheme.bodySmall, // Use a smaller font size
                  textAlign: TextAlign.right,
                ),
              ],
            ),
            subtitle: Row(
              children: <Widget>[
                Expanded(
                  flex: 1,
                  child: Text(
                    'Duration: ${formatDuration(session.durationInSeconds)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Amount: ${formatMoney(session.amount)}',
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A card to display session information for all players.
class AllPlayersCard extends StatelessWidget {
  final SessionPanelItem session;
  final bool isSelected;
  final ValueChanged<int?>? onSessionSelected;

  const AllPlayersCard({
    super.key,
    required this.session,
    required this.isSelected,
    this.onSessionSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      color: isSelected ? Colors.blue.shade100 : null,
      child: MouseRegion(
        onHover: (PointerHoverEvent event) {},
        child: InkWell(
          onTap: () {
            onSessionSelected?.call(session.sessionId);
          },
          child: ListTile(
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    '${session.name}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  'Session: ${session.sessionId}',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.right,
                ),
              ],
            ),
            subtitle: Row(
              children: <Widget>[
                Expanded(
                  flex: 8,
                  child: Text(
                    '${isoFormatEpoch(session.startEpoch)} - ${maybe_isoFormatEpoch(session.stopEpoch, "ongoing")}',
                    textAlign: TextAlign.left,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    formatDuration(session.durationInSeconds),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    formatMoney(session.amount),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}