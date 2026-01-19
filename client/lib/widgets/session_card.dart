// client/lib/widgets/session_card.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/player_selection_item.dart';
import '../models/session.dart';
import '../models/session_panel_item.dart';
import '../providers/api_provider.dart';
import '../providers/time_provider.dart';
import 'dialogs.dart';

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

  Future<void> _stopSession(BuildContext context, SessionPanelItem session,
      double liveBalance) async {
    final apiProvider = Provider.of<ApiProvider>(context, listen: false);
    final timeProvider = Provider.of<TimeProvider>(context, listen: false);

    // **CHANGE**: Capture the time immediately when the user taps "Stop".
    // This effectively "freezes" the session cost at the moment of interaction.
    final DateTime frozenStopTime = timeProvider.currentTime;

    Future<void> handleStopAction() async {
      final fullSession = Session(
        sessionId: session.sessionId,
        playerId: session.playerId,
        startEpoch: session.startEpoch,
        // **CHANGE**: Use the frozen time for the database update.
        stopEpoch: frozenStopTime.millisecondsSinceEpoch ~/ 1000,
      );
      await apiProvider.updateSession(fullSession);
    }

    if (liveBalance < 0) {
      showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            backgroundColor: Colors.red.shade100,
            title: Text('Stop Session for ${session.name}?'),
            content: Text(
                'The player\'s balance is currently ${_formatMaybeMoney(liveBalance)}.'),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              TextButton(
                child: const Text('Stop Session'),
                onPressed: () async {
                  final navigator = Navigator.of(dialogContext);
                  try {
                    await handleStopAction();
                    navigator.pop();
                  } catch (e) {
                    // Handle error if necessary
                  }
                },
              ),
              FilledButton(
                child: const Text('Add Money'),
                onPressed: () async {
                  // Close this dialog, then show the Add Money dialog and finish.
                  Navigator.of(dialogContext).pop();

                  // Wait for the next frame to avoid gesture conflict
                  await Future.delayed(Duration.zero);

                  // Check context.mounted, not just mounted (StatelessWidget doesn't have mounted)
                  if (!context.mounted) return;

                  final player = PlayerSelectionItem(
                      playerId: session.playerId,
                      name: session.name,
                      balance: session.balance,
                      hasActiveSession: true);

                  await showAddMoneyDialog(context, player: player);
                },
              ),
            ],
          );
        },
      );
    } else {
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
                  try {
                    await handleStopAction();
                    navigator.pop();
                  } catch (e) {
                    // Handle error if necessary
                  }
                },
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final apiProvider = Provider.of<ApiProvider>(context, listen: false);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      color: isSelected ? Colors.blue.shade100 : null,
      child: Consumer<TimeProvider>(
        builder: (context, timeProvider, child) {
          final double liveBalance = apiProvider.getDynamicBalance(
            playerId: session.playerId,
            currentTime: timeProvider.currentTime,
            clubSessionStartDateTime: clubSessionStartDateTime,
          );

          return InkWell(
            onTap: () {
              if (session.stopEpoch == null) {
                _stopSession(context, session, liveBalance);
              } else {
                onSessionSelected?.call(session.sessionId);
              }
            },
            child: child,
          );
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
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  Consumer<TimeProvider>(
                    builder: (context, timeProvider, child) {
                      if (session.stopEpoch == null) {
                        final double liveBalance =
                            apiProvider.getDynamicBalance(
                          playerId: session.playerId,
                          currentTime: timeProvider.currentTime,
                          clubSessionStartDateTime: clubSessionStartDateTime,
                        );
                        Color balanceColor =
                            Theme.of(context).textTheme.bodyLarge?.color ??
                                Colors.black;
                        if (liveBalance <= 0) {
                          balanceColor = Colors.red.shade700;
                        } else if (liveBalance <= 1) {
                          balanceColor = Colors.yellow.shade800;
                        } else {
                          balanceColor = Colors.green.shade800;
                        }

                        return Text(
                          'Balance: ${_formatMaybeMoney(liveBalance)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: balanceColor,
                          ),
                        );
                      } else {
                        return Text(
                          'Session: ${session.sessionId}',
                          style: Theme.of(context).textTheme.bodySmall,
                        );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Consumer<TimeProvider>(
                builder: (context, timeProvider, child) {
                  final effectiveStopEpoch = session.stopEpoch ??
                      (timeProvider.currentTime.millisecondsSinceEpoch ~/ 1000);

                  final amount =
                      (max(0, effectiveStopEpoch - session.startEpoch) /
                              3600.0 *
                              session.rate)
                          .roundToDouble();
                  final durationInSeconds =
                      max(0, effectiveStopEpoch - session.startEpoch);

                  return Row(
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
                          Text(
                              'Duration: ${_formatDuration(durationInSeconds)}'),
                          const SizedBox(width: 16),
                          Text('Amount: ${_formatMaybeMoney(amount)}'),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}