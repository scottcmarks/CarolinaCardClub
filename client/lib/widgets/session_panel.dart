// client/lib/widgets/session_panel.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../models/player_selection_item.dart';
import '../providers/app_settings_provider.dart';
import '../providers/api_provider.dart';
import '../providers/time_provider.dart';
import '../models/session.dart';
import '../models/session_panel_item.dart';

String _formatMaybeMoney(double? price) {
  if (price == null) return '';
  return NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(price);
}

String _formatDuration(int totalSeconds) {
  final int totalMinutes = totalSeconds ~/ 60;
  final int hours = totalMinutes ~/ 60;
  final int minutes = totalMinutes.remainder(60);
  return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
}

class SessionPanel extends StatefulWidget {
  final int? selectedPlayerId;
  final int? selectedSessionId;
  final ValueChanged<int?>? onSessionSelected;
  // **MODIFICATION**: Add onPlayerSelected callback.
  final ValueChanged<int?>? onPlayerSelected;
  final int? newlyAddedSessionId;
  final DateTime? clubSessionStartDateTime;
  final ValueChanged<DateTime?> onClubSessionTimeChanged;

  const SessionPanel({
    super.key,
    this.selectedPlayerId,
    this.selectedSessionId,
    this.onSessionSelected,
    this.onPlayerSelected,
    this.newlyAddedSessionId,
    required this.clubSessionStartDateTime,
    required this.onClubSessionTimeChanged,
  });

  @override
  State<SessionPanel> createState() => SessionPanelState();
}

class SessionPanelState extends State<SessionPanel> {
  final ItemScrollController _scrollController = ItemScrollController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateSessionFilter();
      }
    });
  }

  @override
  void didUpdateWidget(covariant SessionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool oldOnlyActive = oldWidget.clubSessionStartDateTime != null;
    final bool newOnlyActive = widget.clubSessionStartDateTime != null;
    if (oldWidget.selectedPlayerId != widget.selectedPlayerId || oldOnlyActive != newOnlyActive) {
      _updateSessionFilter();
    }
    if (widget.newlyAddedSessionId != null &&
        widget.newlyAddedSessionId != oldWidget.newlyAddedSessionId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToSession(widget.newlyAddedSessionId!);
        }
      });
    }
  }

  void _updateSessionFilter() {
    final apiProvider = Provider.of<ApiProvider>(context, listen: false);
    apiProvider.fetchSessionPanelList(
      playerId: widget.selectedPlayerId,
      onlyActive: widget.clubSessionStartDateTime != null,
    );
  }

  void _scrollToSession(int sessionId) {
    final sessions = Provider.of<ApiProvider>(context, listen: false).sessions;
    final index = sessions.indexWhere((s) => s.sessionId == sessionId);
    if (index != -1 && mounted && _scrollController.isAttached) {
      _scrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showStopClubSessionDialog(BuildContext context) {
    final apiProvider = Provider.of<ApiProvider>(context, listen: false);
    final timeProvider = Provider.of<TimeProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('End Club Session?'),
          content: const Text(
              'This will stop all active sessions and back up the database. Are you sure?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text('OK'),
              onPressed: () async {
                final navigator = Navigator.of(dialogContext);
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                try {
                  await apiProvider.stopAllSessions(timeProvider.currentTime);
                  navigator.pop();
                  if (!mounted) return;
                  widget.onClubSessionTimeChanged(null);
                } catch (e) {
                  navigator.pop();
                  if (!mounted) return;
                  scaffoldMessenger.showSnackBar(
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
    final appSettings = Provider.of<AppSettingsProvider>(context, listen: false).currentSettings;
    final now = Provider.of<TimeProvider>(context, listen: false).currentTime;
    final defaultStartTime = appSettings.defaultSessionStartTime ?? const TimeOfDay(hour: 19, minute: 30);
    final defaultSessionStartDateTime = DateTime(now.year, now.month, now.day, defaultStartTime.hour, defaultStartTime.minute);

    final apiProvider = context.watch<ApiProvider>();

    String playerFilterText;
    if (widget.selectedPlayerId == null) {
      playerFilterText = 'for all players';
    } else {
      final selectedPlayer = apiProvider.players.firstWhere(
        (p) => p.playerId == widget.selectedPlayerId,
        orElse: () => PlayerSelectionItem(playerId: 0, name: 'Unknown', balance: 0, hasActiveSession: false),
      );
      playerFilterText = 'for ${selectedPlayer.name}';
    }

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
          playerFilterText: playerFilterText,
          // **MODIFICATION**: Pass player selection info down to the header.
          selectedPlayerId: widget.selectedPlayerId,
          onPlayerSelected: widget.onPlayerSelected,
        ),
        const Divider(),
        Expanded(
          child: Builder(
            builder: (context) {
              final sessions = apiProvider.sessions;
              if (sessions.isEmpty) {
                  return const Center(child: Text('No sessions found.'));
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
                    allSessions: sessions,
                  );
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
  final String playerFilterText;
  // **MODIFICATION**: Add player selection parameters.
  final int? selectedPlayerId;
  final ValueChanged<int?>? onPlayerSelected;

  const SessionPanelHeader({
    super.key,
    required this.clubSessionStartDateTime,
    required this.defaultSessionStartDateTime,
    required this.onToggleClubSessionTime,
    required this.playerFilterText,
    this.selectedPlayerId,
    this.onPlayerSelected,
  });

  @override
  Widget build(BuildContext context) {
    final bool showOnlyActiveSessions = clubSessionStartDateTime != null;
    final line1 = showOnlyActiveSessions ? 'Active sessions only' : 'All sessions';
    final combinedText = '$line1\n$playerFilterText';

    // **MODIFICATION**: Logic for the right-side button's state.
    final bool isPlayerSelected = selectedPlayerId != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Left-side Button ---
          Expanded(
            child: InkWell(
              onTap: onToggleClubSessionTime,
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
          ),
          // --- Right-side Button ---
          InkWell(
            // If a player is selected, the action is to deselect them. Otherwise, do nothing.
            onTap: isPlayerSelected ? () => onPlayerSelected?.call(null) : null,
            borderRadius: BorderRadius.circular(4.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
              // Show a "depressed" background color if a player is selected.
              decoration: BoxDecoration(
                color: isPlayerSelected ? Theme.of(context).highlightColor : Colors.transparent,
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: Text(
                combinedText,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
              ),
            ),
          ),
        ],
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
  final List<SessionPanelItem> allSessions;

  const SessionCard({
    super.key,
    required this.session,
    required this.isSelected,
    this.onSessionSelected,
    this.clubSessionStartDateTime,
    required this.showPlayerName,
    required this.allSessions,
  });

  double _calculateRoundedAmount({
    required int startEpoch,
    required int stopEpoch,
    required double rate,
    required DateTime? clubSessionStartDateTime,
  }) {
    final effectiveStartEpoch = clubSessionStartDateTime != null
        ? max(startEpoch, clubSessionStartDateTime.millisecondsSinceEpoch ~/ 1000)
        : startEpoch;
    final durationInSeconds = max(0, stopEpoch - effectiveStartEpoch);
    final amount = (durationInSeconds / 3600.0) * rate;
    return amount.roundToDouble();
  }

  Future<void> _stopSession(BuildContext context, SessionPanelItem session) async {
    final apiProvider = Provider.of<ApiProvider>(context, listen: false);
    final timeProvider = Provider.of<TimeProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Stop Session for ${session.name}?'),
          content: const Text('Are you sure you want to stop this session?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text('OK'),
              onPressed: () async {
                 final navigator = Navigator.of(dialogContext);
                 final scaffoldMessenger = ScaffoldMessenger.of(context);
                 try {
                   final fullSession = Session(
                     sessionId: session.sessionId,
                     playerId: session.playerId,
                     startEpoch: session.startEpoch,
                     stopEpoch: timeProvider.currentTime.millisecondsSinceEpoch ~/ 1000,
                   );
                   await apiProvider.updateSession(fullSession);
                   navigator.pop();
                 } catch (e) {
                   navigator.pop();
                   if (!scaffoldMessenger.mounted) return;
                   scaffoldMessenger.showSnackBar(
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
          child: Consumer<TimeProvider>(
            builder: (context, timeProvider, child) {
              final effectiveStopEpoch = session.stopEpoch ??
                  (timeProvider.currentTime.millisecondsSinceEpoch ~/ 1000);

              final amount = _calculateRoundedAmount(
                startEpoch: session.startEpoch,
                stopEpoch: effectiveStopEpoch,
                rate: session.rate,
                clubSessionStartDateTime: clubSessionStartDateTime,
              );
              final durationInSeconds = max(0, effectiveStopEpoch - session.startEpoch);

              double liveBalance = session.balance;
              Color balanceColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

              if (session.stopEpoch == null) {
                final activeSessionsForPlayer = allSessions.where(
                  (s) => s.playerId == session.playerId && s.stopEpoch == null
                );
                double totalActiveAmount = 0;
                for (final activeSession in activeSessionsForPlayer) {
                  totalActiveAmount += _calculateRoundedAmount(
                    startEpoch: activeSession.startEpoch,
                    stopEpoch: timeProvider.currentTime.millisecondsSinceEpoch ~/ 1000,
                    rate: activeSession.rate,
                    clubSessionStartDateTime: clubSessionStartDateTime,
                  );
                }
                liveBalance = session.balance - totalActiveAmount;
                if (liveBalance <= 0) {
                  balanceColor = Colors.red.shade700;
                } else if (liveBalance <= 1) {
                  balanceColor = Colors.yellow.shade800;
                } else {
                  balanceColor = Colors.green.shade800;
                }
              }

              return Column(
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
                      if (session.stopEpoch == null)
                        Text(
                          'Balance: ${_formatMaybeMoney(liveBalance)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: balanceColor,
                          ),
                        )
                      else
                        Text(
                          'Session: ${session.sessionId}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${DateFormat('MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(session.startEpoch * 1000))} - ${session.stopEpoch == null ? "ongoing" : DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(session.stopEpoch! * 1000))}',
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Duration: ${_formatDuration(durationInSeconds)}'),
                          const SizedBox(width: 16),
                          Text('Amount: ${_formatMaybeMoney(amount)}'),
                        ],
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}