// lib/widgets/session_panel.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../providers/api_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/time_provider.dart';
import '../models/app_settings.dart';
import '../models/session.dart';
import '../models/session_panel_item.dart';

class SessionPanel extends StatefulWidget {
  final ValueChanged<int?>? onSessionSelected;
  final int? selectedPlayerId;
  final int? selectedSessionId;
  final int? newlyAddedSessionId;

  const SessionPanel({
    super.key,
    this.onSessionSelected,
    this.selectedPlayerId,
    this.selectedSessionId,
    this.newlyAddedSessionId,
  });

  @override
  _SessionPanelState createState() => _SessionPanelState();
}

class _SessionPanelState extends State<SessionPanel> {
  DateTime? _clubSessionStartDateTime;
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();

  void _showStopClubSessionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('End Club Session'),
          content: const Text('Close all active sessions and trigger a server backup?'),
          actions: <Widget>[
            TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(dialogContext).pop()),
            TextButton(
              child: const Text('OK'),
              onPressed: () async {
                final apiProvider = Provider.of<ApiProvider>(context, listen: false);
                final appSettingsProvider = Provider.of<AppSettingsProvider>(context, listen: false);
                await apiProvider.triggerBackup();
                setState(() { _clubSessionStartDateTime = null; });
                appSettingsProvider.setShowOnlyActiveSessions(false);
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _toggleClubSessionTime(DateTime defaultTime, AppSettingsProvider appSettingsProvider) {
    if (_clubSessionStartDateTime != null) {
      _showStopClubSessionDialog(context);
    } else {
      setState(() { _clubSessionStartDateTime = defaultTime; });
      appSettingsProvider.setShowOnlyActiveSessions(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appSettingsProvider = Provider.of<AppSettingsProvider>(context);
    final timeProvider = Provider.of<TimeProvider>(context, listen: false);

    final AppSettings currentSettings = appSettingsProvider.currentSettings;
    final bool showOnlyActiveSessions = currentSettings.showOnlyActiveSessions;
    final TimeOfDay defaultSessionStartTime = currentSettings.defaultSessionStartTime ?? const TimeOfDay(hour: 19, minute: 30);
    final DateTime now = timeProvider.currentTime;

    final DateTime defaultSessionStartDateTime = DateTime(now.year, now.month, now.day, defaultSessionStartTime.hour, defaultSessionStartTime.minute);
    final DateTime effectiveClubStartTime = _clubSessionStartDateTime ?? defaultSessionStartDateTime;

    return Column(
      children: [
        SessionPanelHeader(
          clubSessionStartDateTime: _clubSessionStartDateTime,
          defaultSessionStartDateTime: defaultSessionStartDateTime,
          showOnlyActiveSessions: showOnlyActiveSessions,
          onTap: () => _toggleClubSessionTime(defaultSessionStartDateTime, appSettingsProvider),
        ),
        const Divider(),
        Expanded(
          child: SessionPanelBody(
            showOnlyActiveSessions: showOnlyActiveSessions,
            selectedPlayerId: widget.selectedPlayerId,
            selectedSessionId: widget.selectedSessionId,
            onSessionSelected: widget.onSessionSelected,
            clubSessionStartTime: effectiveClubStartTime,
            newlyAddedSessionId: widget.newlyAddedSessionId,
            itemScrollController: _itemScrollController,
            itemPositionsListener: _itemPositionsListener,
          ),
        ),
      ],
    );
  }
}

// --- Helper Functions & Widgets ---
String formatMoney(double? price) => price != null ? '\$${price.toStringAsFixed(2)}' : '';
String formatDuration(int? totalSeconds) {
  if (totalSeconds == null) return '';
  final int hours = totalSeconds ~/ 3600;
  final int minutes = (totalSeconds % 3600) ~/ 60;
  return '${hours}h${minutes.toString().padLeft(2, '0')}m';
}
String isoFormatEpoch(int seconds) => DateFormat('yyyy-MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(seconds * 1000));
String maybeIsoFormatEpoch(int? seconds, String ifNull) => seconds != null ? isoFormatEpoch(seconds) : ifNull;

class SessionPanelHeader extends StatelessWidget {
  final DateTime? clubSessionStartDateTime;
  final DateTime defaultSessionStartDateTime;
  final bool showOnlyActiveSessions;
  final VoidCallback onTap;
  const SessionPanelHeader({super.key, required this.clubSessionStartDateTime, required this.defaultSessionStartDateTime, required this.showOnlyActiveSessions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          InkWell(
            onTap: onTap,
            child: Text(
              (clubSessionStartDateTime != null)
                  ? 'Club session started at ${DateFormat("HH:mm").format(clubSessionStartDateTime!)}'
                  : 'Club session starts at ${DateFormat("HH:mm").format(defaultSessionStartDateTime)}',
              style: TextStyle(fontSize: 16, fontStyle: clubSessionStartDateTime != null ? FontStyle.normal : FontStyle.italic),
            ),
          ),
          const Spacer(),
          Text(showOnlyActiveSessions ? 'Active' : 'All', style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}

class SessionPanelBody extends StatelessWidget {
  final bool showOnlyActiveSessions;
  final int? selectedPlayerId;
  final int? selectedSessionId;
  final ValueChanged<int?>? onSessionSelected;
  final DateTime clubSessionStartTime;
  final int? newlyAddedSessionId;
  final ItemScrollController itemScrollController;
  final ItemPositionsListener itemPositionsListener;

  const SessionPanelBody({super.key, required this.showOnlyActiveSessions, required this.clubSessionStartTime, this.selectedPlayerId, this.selectedSessionId, this.onSessionSelected, this.newlyAddedSessionId, required this.itemScrollController, required this.itemPositionsListener});

  @override
  Widget build(BuildContext context) {
    final apiProvider = Provider.of<ApiProvider>(context);
    if (!apiProvider.isServerAvailable) return const Center(child: Text('Server not available.', style: TextStyle(color: Colors.red)));

    return FutureBuilder<List<SessionPanelItem>>(
      future: apiProvider.fetchSessionPanelList(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('No sessions found.'));

        List<SessionPanelItem> sessions = snapshot.data!;
        if (showOnlyActiveSessions) sessions = sessions.where((s) => s.stopEpoch == null).toList();
        if (selectedPlayerId != null) sessions = sessions.where((s) => s.playerId == selectedPlayerId).toList();

        if (newlyAddedSessionId != null) {
          final index = sessions.indexWhere((s) => s.sessionId == newlyAddedSessionId);
          if (index != -1) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              itemScrollController.scrollTo(
                index: index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            });
          }
        }

        return ScrollablePositionedList.builder(
          itemScrollController: itemScrollController,
          itemPositionsListener: itemPositionsListener,
          itemCount: sessions.length,
          itemBuilder: (context, index) {
            final session = sessions[index];
            final isSelected = session.sessionId == selectedSessionId;
            return selectedPlayerId != null
                ? SelectedPlayerCard(session: session, isSelected: isSelected, onSessionSelected: onSessionSelected, clubSessionStartTime: clubSessionStartTime)
                : AllPlayersCard(session: session, isSelected: isSelected, onSessionSelected: onSessionSelected, clubSessionStartTime: clubSessionStartTime);
          },
        );
      },
    );
  }
}

abstract class SessionCard extends StatelessWidget {
  final SessionPanelItem session;
  final bool isSelected;
  final ValueChanged<int?>? onSessionSelected;
  final DateTime clubSessionStartTime;
  const SessionCard({super.key, required this.session, required this.isSelected, required this.onSessionSelected, required this.clubSessionStartTime});

  Map<String, dynamic> _calculateDynamicValues(DateTime currentTime) {
    if (session.stopEpoch != null) {
      return {'duration': session.durationInSeconds, 'amount': session.amount};
    }
    final clubStartEpoch = clubSessionStartTime.millisecondsSinceEpoch ~/ 1000;
    final effectiveStartEpoch = max(session.startEpoch, clubStartEpoch);
    final effectiveEndEpoch = currentTime.millisecondsSinceEpoch ~/ 1000;
    final durationInSeconds = max(0, effectiveEndEpoch - effectiveStartEpoch);
    final fractionalHours = durationInSeconds / 3600.0;
    final amount = (fractionalHours * (session.rate ?? 0.0)).round().toDouble();
    return {'duration': durationInSeconds, 'amount': amount};
  }

  void _handleTap(BuildContext context) {
    if (session.stopEpoch == null) {
      _showStopSessionDialog(context);
    } else {
      onSessionSelected?.call(isSelected ? null : session.sessionId);
    }
  }

  void _showStopSessionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Stop Session'),
          content: Text('Do you want to stop the session for ${session.name}?'),
          actions: <Widget>[
            TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(dialogContext).pop()),
            TextButton(
              child: const Text('OK'),
              onPressed: () async {
                final apiProvider = Provider.of<ApiProvider>(context, listen: false);
                final timeProvider = Provider.of<TimeProvider>(context, listen: false);
                final updatedSession = Session(
                  sessionId: session.sessionId,
                  playerId: session.playerId,
                  startEpoch: session.startEpoch,
                  stopEpoch: timeProvider.currentTime.millisecondsSinceEpoch ~/ 1000,
                );
                await apiProvider.updateSession(updatedSession);
                Navigator.of(dialogContext).pop();
                onSessionSelected?.call(null);
              },
            ),
          ],
        );
      },
    );
  }
}

class SelectedPlayerCard extends SessionCard {
  const SelectedPlayerCard({super.key, required super.session, required super.isSelected, required super.onSessionSelected, required super.clubSessionStartTime});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      color: isSelected ? Colors.blue.shade100 : null,
      child: InkWell(
        onTap: () => _handleTap(context),
        child: ListTile(
          title: Row(children: [
            Expanded(child: Text('${isoFormatEpoch(session.startEpoch)} - ${maybeIsoFormatEpoch(session.stopEpoch, "ongoing")}', overflow: TextOverflow.ellipsis)),
            Text('Session: ${session.sessionId}', style: Theme.of(context).textTheme.bodySmall),
          ]),
          subtitle: Consumer<TimeProvider>(
            builder: (context, timeProvider, child) {
              final dynamicValues = _calculateDynamicValues(timeProvider.currentTime);
              return Row(children: <Widget>[
                Expanded(flex: 1, child: Text('Duration: ${formatDuration(dynamicValues['duration'])}')),
                Expanded(flex: 1, child: Text('Amount: ${formatMoney(dynamicValues['amount'])}', textAlign: TextAlign.right)),
              ]);
            },
          ),
        ),
      ),
    );
  }
}

class AllPlayersCard extends SessionCard {
  const AllPlayersCard({super.key, required super.session, required super.isSelected, required super.onSessionSelected, required super.clubSessionStartTime});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      color: isSelected ? Colors.blue.shade100 : null,
      child: InkWell(
        onTap: () => _handleTap(context),
        child: ListTile(
          title: Row(children: [
            Expanded(child: Text(session.name, overflow: TextOverflow.ellipsis)),
            Text('Session: ${session.sessionId}', style: Theme.of(context).textTheme.bodySmall),
          ]),
          subtitle: Consumer<TimeProvider>(
            builder: (context, timeProvider, child) {
              final dynamicValues = _calculateDynamicValues(timeProvider.currentTime);
              return Row(children: <Widget>[
                Expanded(flex: 8, child: Text('${isoFormatEpoch(session.startEpoch)} - ${maybeIsoFormatEpoch(session.stopEpoch, "ongoing")}')),
                Expanded(flex: 2, child: Text(formatDuration(dynamicValues['duration']), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text(formatMoney(dynamicValues['amount']), textAlign: TextAlign.right)),
              ]);
            },
          ),
        ),
      ),
    );
  }
}
