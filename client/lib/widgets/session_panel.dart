// client/lib/widgets/session_panel.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../models/player_selection_item.dart';
import '../providers/app_settings_provider.dart';
import '../providers/api_provider.dart';
import '../providers/time_provider.dart';
import 'session_card.dart';        // **NEW IMPORT**
import 'session_panel_header.dart'; // **NEW IMPORT**

class SessionPanel extends StatefulWidget {
  final int? selectedPlayerId;
  final int? selectedSessionId;
  final ValueChanged<int?>? onSessionSelected;
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
    if (oldWidget.selectedPlayerId != widget.selectedPlayerId ||
        oldOnlyActive != newOnlyActive) {
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

    final bool hasActiveSessions =
        apiProvider.sessions.any((s) => s.stopEpoch == null);

    if (!hasActiveSessions) {
      widget.onClubSessionTimeChanged(null);
      return;
    }

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
    final appSettings = Provider.of<AppSettingsProvider>(context, listen: false)
        .currentSettings;
    final now = Provider.of<TimeProvider>(context, listen: false).currentTime;
    final defaultStartTime = appSettings.defaultSessionStartTime ??
        const TimeOfDay(hour: 19, minute: 30);
    final defaultSessionStartDateTime = DateTime(now.year, now.month, now.day,
        defaultStartTime.hour, defaultStartTime.minute);

    final apiProvider = context.watch<ApiProvider>();

    String playerFilterText;
    if (widget.selectedPlayerId == null) {
      playerFilterText = 'for all players';
    } else {
      final selectedPlayer = apiProvider.players.firstWhere(
        (p) => p.playerId == widget.selectedPlayerId,
        orElse: () => PlayerSelectionItem(
            playerId: 0, name: 'Unknown', balance: 0, hasActiveSession: false),
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
                  final isSelected =
                      session.sessionId == widget.selectedSessionId;
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