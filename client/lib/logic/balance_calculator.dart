// client/lib/logic/balance_calculator.dart

import 'dart:math';

import '../models/player_selection_item.dart';
import '../models/session_panel_item.dart';

class BalanceCalculator {
  /// Calculates the rounded cost of a session based on duration and rate.
  static double calculateRoundedAmount({
    required int startEpoch,
    required int stopEpoch,
    required double rate,
    required DateTime? clubSessionStartDateTime,
  }) {
    final effectiveStartEpoch = clubSessionStartDateTime != null
        ? max(
            startEpoch, clubSessionStartDateTime.millisecondsSinceEpoch ~/ 1000)
        : startEpoch;
    final durationInSeconds = max(0, stopEpoch - effectiveStartEpoch);
    final amount = (durationInSeconds / 3600.0) * rate;
    return amount.roundToDouble();
  }

  /// Calculates the live balance for a player.
  static double getDynamicBalance({
    required int playerId,
    required DateTime currentTime,
    required DateTime? clubSessionStartDateTime,
    required List<PlayerSelectionItem> players,
    required List<SessionPanelItem> sessions,
  }) {
    final player = players.firstWhere(
      (p) => p.playerId == playerId,
      orElse: () => PlayerSelectionItem(
          playerId: 0, name: '', balance: 0, hasActiveSession: false),
    );

    if (!player.hasActiveSession) {
      return player.balance;
    }

    final activeSessionsForPlayer =
        sessions.where((s) => s.playerId == playerId && s.stopEpoch == null);

    double totalActiveAmount = 0;
    for (final activeSession in activeSessionsForPlayer) {
      totalActiveAmount += calculateRoundedAmount(
        startEpoch: activeSession.startEpoch,
        stopEpoch: currentTime.millisecondsSinceEpoch ~/ 1000,
        rate: activeSession.rate,
        clubSessionStartDateTime: clubSessionStartDateTime,
      );
    }

    return player.balance - totalActiveAmount;
  }
}