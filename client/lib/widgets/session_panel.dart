// client/lib/widgets/session_panel.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../providers/app_settings_provider.dart';
import '../providers/api_provider.dart';
import '../providers/time_provider.dart';
import '../models/session.dart';
import '../models/session_panel_item.dart';

// Helper Functions
String _formatMaybeMoney(double? price) {
  if (price == null) return '';
  return '\$${price.toStringAsFixed(2)}';
}

String _formatDuration(int totalSeconds) {
  final int totalMinutes = totalSeconds ~/ 60;
  final int hours = totalMinutes ~/ 60;
  final int minutes = totalMinutes.remainder(60);
  return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
}

String _formatMaybeDuration(int? maybeSeconds) {
  return (maybeSeconds != null) ? _formatDuration(maybeSeconds) : '';
}

class SessionPanel extends StatefulWidget {
  final int? selectedPlayerId;
  final int? selectedSessionId;
  final ValueChanged<int?>? onSessionSelected;
  final int? newlyAddedSessionId;
  final DateTime? clubSessionStartDateTime;
  final ValueChanged<DateTime?> onClubSessionTimeChanged;

  const SessionPanel({
    super.key,
    this.selectedPlayerId,
    this.selectedSessionId,
    this.onSessionSelected,
    this.newlyAddedSessionId,
    required this.clubSessionStartDateTime,
    required this.onClubSessionTimeChanged,
  });

  @override
  State<SessionPanel> createState() => _SessionPanelState();
}

class _SessionPanelState extends State<SessionPanel> {
  final ItemScrollController _scrollController = ItemScrollController();

  @override
  void didUpdateWidget(covariant SessionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.newlyAddedSessionId != null &&
        widget.newlyAddedSessionId != oldWidget.newlyAddedSessionId) {
      // Use a post-frame callback to ensure the list has been built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToSession(widget.newlyAddedSessionId!);
        }
      });
    }
  }

  void _scrollToSession(int sessionId) {
    // This logic needs the index of the session, not the ID.
    // The FutureBuilder will need to handle finding the index.
    // We will handle this inside the FutureBuilder's builder.
  }

  void _showStopClubSessionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('End Club Session?'),
          content: const Text(
              'This will stop all active sessions at the current time. Are you sure?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('OK'),
              onPressed: () async {
                Navigator.of(context).pop();
                final apiProvider = Provider.of<ApiProvider>(context, listen: false);
                try {
                  await apiProvider.backupDatabase();
                   // Notify parent that the session time has been cleared.
                  widget.onClubSessionTimeChanged(null);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error stopping sessions: $e')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final apiProvider = Provider.of<ApiProvider>(context);
    final appSettings = Provider.of<AppSettingsProvider>(context, listen: false).currentSettings;
    final now = Provider.of<TimeProvider>(context, listen: false).currentTime;

    // Provide a default if the setting is null
    final defaultStartTime = appSettings.defaultSessionStartTime ?? const TimeOfDay(hour: 19, minute: 30);

    final defaultSessionStartDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      defaultStartTime.hour,
      defaultStartTime.minute,
    );

    return Column(
      children: [
        SessionPanelHeader(
          clubSessionStartDateTime: widget.clubSessionStartDateTime,
          defaultSessionStartDateTime: defaultSessionStartDateTime,
          onToggleClubSessionTime: () {
            if (widget.clubSessionStartDateTime == null) {
              widget.onClubSessionTimeChanged(defaultSessionStartDateTime);
            } else {
              _showStopClubSessionDialog(context);
            }
          },
        ),
        const Divider(),
        Expanded(
          child: Consumer<ApiProvider>(
            builder: (context, apiProvider, child) {
              if (apiProvider.serverStatus == ServerStatus.connecting) {
                return const Center(child: Text('Connecting to server...'));
              }
              if (apiProvider.serverStatus == ServerStatus.disconnected) {
                return const Center(child: Text('Disconnected from server.', style: TextStyle(color: Colors.red)));
              }
              return FutureBuilder<List<SessionPanelItem>>(
                future: apiProvider.fetchSessionPanelList(playerId: widget.selectedPlayerId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error loading sessions: ${snapshot.error}', style: TextStyle(color: Colors.red)));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No sessions found.'));
                  } else {
                    List<SessionPanelItem> sessions = snapshot.data!;
                     if (widget.newlyAddedSessionId != null) {
                      final index = sessions.indexWhere((s) => s.sessionId == widget.newlyAddedSessionId);
                      if (index != -1) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                           if (mounted && _scrollController.isAttached) {
                            _scrollController.scrollTo(
                              index: index,
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeInOut,
                            );
                           }
                        });
                      }
                    }
                    return ScrollablePositionedList.builder(
                      itemScrollController: _scrollController,
                      key: const PageStorageKey<String>('SessionListScrollPosition'),
                      itemCount: sessions.length,
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        final isSelected = session.sessionId == widget.selectedSessionId;
                        return SessionCard(
                          session: session,
                          isSelected: isSelected,
                          onSessionSelected: widget.onSessionSelected,
                          clubSessionStartDateTime: widget.clubSessionStartDateTime,
                          showPlayerName: widget.selectedPlayerId == null,
                        );
                      },
                    );
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class SessionPanelHeader extends StatelessWidget {
  final DateTime? clubSessionStartDateTime;
  final DateTime defaultSessionStartDateTime;
  final VoidCallback onToggleClubSessionTime;

  const SessionPanelHeader({
    super.key,
    required this.clubSessionStartDateTime,
    required this.defaultSessionStartDateTime,
    required this.onToggleClubSessionTime,
  });

  @override
  Widget build(BuildContext context) {
    final bool showOnlyActiveSessions = clubSessionStartDateTime != null;
    return InkWell(
      onTap: onToggleClubSessionTime,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                showOnlyActiveSessions
                    ? 'Club session started at ${DateFormat("yyyy-MM-dd HH:mm").format(clubSessionStartDateTime!)}'
                    : 'Tap to start club session at ${DateFormat("yyyy-MM-dd HH:mm").format(defaultSessionStartDateTime)}',
                style: TextStyle(
                    fontSize: 16,
                    fontStyle: showOnlyActiveSessions
                        ? FontStyle.normal
                        : FontStyle.italic),
              ),
            ),
            Text(
              showOnlyActiveSessions ? 'Active' : 'All',
              style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}

class SessionCard extends StatelessWidget {
  final SessionPanelItem session;
  final bool isSelected;
  final ValueChanged<int?>? onSessionSelected;
  final DateTime? clubSessionStartDateTime;
  final bool showPlayerName;

  const SessionCard({
    super.key,
    required this.session,
    required this.isSelected,
    this.onSessionSelected,
    this.clubSessionStartDateTime,
    required this.showPlayerName,
  });

  Future<void> _stopSession(BuildContext context, SessionPanelItem session) async {
    final apiProvider = Provider.of<ApiProvider>(context, listen: false);
    final timeProvider = Provider.of<TimeProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Stop Session for ${session.name}?'),
          content: const Text('Are you sure you want to stop this session?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('OK'),
              onPressed: () async {
                 try {
                   final fullSession = Session(
                     sessionId: session.sessionId,
                     playerId: session.playerId,
                     startEpoch: session.startEpoch,
                     stopEpoch: timeProvider.currentTime.millisecondsSinceEpoch ~/ 1000,
                   );
                   await apiProvider.updateSession(fullSession);
                   Navigator.of(context).pop();
                 } catch (e) {
                   Navigator.of(context).pop();
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text('Failed to stop session: $e')),
                   );
                 }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      color: isSelected ? Colors.blue.shade100 : null,
      child: InkWell(
        onTap: () {
          if (session.stopEpoch == null) {
            _stopSession(context, session);
          } else {
            onSessionSelected?.call(session.sessionId);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (showPlayerName)
                    Expanded(
                      child: Text(
                        session.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  Text(
                    'Session: ${session.sessionId}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${DateFormat('MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(session.startEpoch * 1000))} - ${session.stopEpoch == null ? "ongoing" : DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(session.stopEpoch! * 1000))}',
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Consumer<TimeProvider>(
                    builder: (context, timeProvider, child) {
                      final effectiveStopEpoch = session.stopEpoch ??
                          (timeProvider.currentTime.millisecondsSinceEpoch ~/ 1000);

                      final effectiveStartEpoch = clubSessionStartDateTime != null
                          ? max(session.startEpoch, clubSessionStartDateTime!.millisecondsSinceEpoch ~/ 1000)
                          : session.startEpoch;

                      final durationInSeconds = max(0, effectiveStopEpoch - effectiveStartEpoch);
                      final amount = (durationInSeconds / 3600.0) * session.rate;

                      return Row(
                        children: [
                          Text('Duration: ${_formatDuration(durationInSeconds)}'),
                          const SizedBox(width: 16),
                          Text('Amount: ${_formatMaybeMoney(amount.roundToDouble())}'),
                        ],
                      );
                    },
                  ),
                  Text('Balance: ${_formatMaybeMoney(session.balance)}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
