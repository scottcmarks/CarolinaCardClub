// client/lib/logic/balance_calculator.dart

import '../models/player_selection_item.dart';
import '../models/session_panel_item.dart';

class BalanceCalculator {
  static double getDynamicBalance({
    required int playerId,
    required DateTime currentTime,
    required DateTime? clubSessionStartDateTime,
    required List<PlayerSelectionItem> players,
    required List<SessionPanelItem> sessions,
  }) {
    // 1. Get Base Balance
    final player = players.firstWhere(
      (p) => p.playerId == playerId,
      orElse: () => PlayerSelectionItem(playerId: -1, name: 'Unknown', balance: 0.0),
    );

    double currentBalance = player.balance;

    // 2. Find Active Session
    final activeSession = sessions.firstWhere(
      (s) => s.playerId == playerId && s.stopTime == null,
      orElse: () => SessionPanelItem(
          sessionId: -1,
          playerId: -1,
          name: '',
          startTime: DateTime.now(),
          amount: 0,
          balance: 0,
          rate: 0),
    );

    // 3. Calculate "Live" Cost
    if (activeSession.sessionId != -1) {
      if (activeSession.isPrepaid) {
        // Prepaid Logic: Deduct the fixed cost immediately.
        // The rate is effectively $0/hr after the buy-in.
        currentBalance -= activeSession.prepayAmount;
      } else {
        // Standard Logic: Deduct based on time duration
        final duration = currentTime.difference(activeSession.startTime);
        final hours = duration.inSeconds / 3600.0;
        final currentSessionCost = hours * activeSession.rate;
        currentBalance -= currentSessionCost;
      }
    }

    return currentBalance;
  }
}
