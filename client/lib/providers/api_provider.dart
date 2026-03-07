// client/lib/providers/api_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/app_settings.dart';
import '../models/player_selection_item.dart';
import '../models/session.dart';
import '../models/poker_table.dart';
import '../services/api_service.dart';
import 'package:db_connection/db_connection.dart';
import 'time_provider.dart';

class ApiProvider with ChangeNotifier {
  final AppSettings settings;
  final DbConnectionProvider connectionProvider;
  final TimeProvider timeProvider;

  late final ApiService _service = ApiService(settings);
  StreamSubscription? _broadcastSubscription;

  List<PlayerSelectionItem> players = [];
  List<Session> sessions = [];
  List<PokerTable> pokerTables = [];

  List<PokerTable> get tables => pokerTables;
  List<PokerTable> get activeTables => pokerTables.where((t) => t.isActive).toList();

  int? selectedPlayerId;
  bool isClubSessionOpen = false;
  int? clubSessionStartEpoch;
  late int defaultSessionHour = settings.defaultSessionHour;
  late int defaultSessionMinute = settings.defaultSessionMinute;

  bool showAllSessions = false;
  bool debugFetchPlayers = false;

  void setShowAllSessions(bool value) {
    showAllSessions = value;
    notifyListeners();
  }

  ApiProvider(this.settings, this.connectionProvider, this.timeProvider) {
    _subscribeToBroadcasts();
  }

  void _subscribeToBroadcasts() {
    _broadcastSubscription = connectionProvider.broadcastStream.listen((message) {
      final event = message['event'];
      if (event == 'state_changed') {
        reloadAll(timeProvider.nowEpoch);
      } else if (event == 'clock_offset') {
        final int offsetSeconds = message['offsetSeconds'] ?? 0;
        timeProvider.setOffset(Duration(seconds: offsetSeconds));
      }
    });
  }

  // ── Computed state ────────────────────────────────────────────────────────

  int getDynamicBalance(PlayerSelectionItem player, int nowEpoch) {
    int balance = player.balance;
    for (final session in sessions.where((s) => s.playerId == player.playerId && s.stopTime == null)) {
      if (!session.isPrepaid) {
        final elapsed = nowEpoch - session.startEpoch;
        if (elapsed > 0) balance -= ((elapsed * session.hourlyRate) / 3600).round();
      }
    }
    return balance;
  }

  int effectiveStartEpoch(int nowEpoch) {
    if (isClubSessionOpen && clubSessionStartEpoch != null && clubSessionStartEpoch! > nowEpoch) {
      return clubSessionStartEpoch!;
    }
    return nowEpoch;
  }

  Session? activeSessionAt(int tableId, int seatNum) {
    final matches = sessions.where((s) =>
        s.pokerTableId == tableId && s.seatNumber == seatNum && s.stopTime == null);
    return matches.isEmpty ? null : matches.first;
  }

  void selectPlayer(int? playerId) {
    selectedPlayerId = playerId;
    notifyListeners();
  }

  List<Session> get displayedSessions {
    Iterable<Session> filtered = sessions;
    if (isClubSessionOpen && !showAllSessions) filtered = filtered.where((s) => s.stopTime == null);
    if (selectedPlayerId != null) filtered = filtered.where((s) => s.playerId == selectedPlayerId);
    final result = filtered.toList()..sort((a, b) => b.startEpoch.compareTo(a.startEpoch));
    return result;
  }

  Map<int, String> getOccupiedSeatsAndNamesForTable(int tableId, {int? seatingPlayerId}) {
    final Map<int, String> occupied = {};
    for (final s in sessions.where((s) => s.pokerTableId == tableId && s.stopTime == null)) {
      if (s.seatNumber != null) occupied[s.seatNumber!] = s.name;
    }

    if (seatingPlayerId != null &&
        seatingPlayerId != settings.floorManagerPlayerId &&
        tableId == settings.floorManagerReservedTable) {
      final fmSeat = settings.floorManagerReservedSeat;
      bool fmHasClosedSession = false;
      if (clubSessionStartEpoch != null) {
        fmHasClosedSession = sessions.any((s) =>
            s.playerId == settings.floorManagerPlayerId &&
            s.startEpoch >= clubSessionStartEpoch! &&
            s.stopTime != null);
      }
      final table = pokerTables.firstWhere((t) => t.pokerTableId == tableId);
      final occupiedOtherSeats = occupied.keys.where((seat) => seat != fmSeat).length;
      if (!(fmHasClosedSession && occupiedOtherSeats >= table.capacity - 1)) {
        if (!occupied.containsKey(fmSeat)) occupied[fmSeat] = 'Reserved';
      }
    }

    return occupied;
  }

  // ── Fetches ───────────────────────────────────────────────────────────────

  Future<void> fetchState() async {
    try {
      final data = await _service.getState();
      isClubSessionOpen = data['Is_Club_Open'] == 1;
      clubSessionStartEpoch = data['Club_Start_Epoch'];
      defaultSessionHour = data['Default_Session_Hour'] ?? settings.defaultSessionHour;
      defaultSessionMinute = data['Default_Session_Minute'] ?? settings.defaultSessionMinute;
      notifyListeners();
    } catch (e) {
      debugPrint('🛑 ERROR [fetchState]: $e');
    }
  }

  Future<void> fetchPlayers(int nowEpoch) async {
    try {
      players = await _service.getPlayers(nowEpoch);
      notifyListeners();
    } catch (e) {
      if (debugFetchPlayers) debugPrint('🛑 ERROR [fetchPlayers]: $e');
    }
  }

  Future<void> fetchTables() async {
    pokerTables = await _service.getTables();
    notifyListeners();
  }

  Future<void> fetchSessions() async {
    try {
      sessions = await _service.getSessions();
      notifyListeners();
    } catch (e) {
      debugPrint('🛑 ERROR [fetchSessions]: $e');
    }
  }

  Future<void> reloadAll(int nowEpoch) async {
    await fetchState();
    await fetchTables();
    await fetchPlayers(nowEpoch);
    await fetchSessions();
  }

  // ── Mutations ─────────────────────────────────────────────────────────────

  Future<void> addSession(Session session, int nowEpoch) async {
    await _service.addSession(session);
    await reloadAll(nowEpoch);
  }

  Future<void> stopSession(int sessionId, int stopEpoch) async {
    await _service.stopSession(sessionId, stopEpoch);
    await reloadAll(stopEpoch);
  }

  Future<void> markAway(int sessionId, int awayEpoch) async {
    await _service.markAway(sessionId, awayEpoch);
    // No reloadAll — server broadcasts state_changed
  }

  Future<void> markReturn(int sessionId) async {
    await _service.markReturn(sessionId);
    // No reloadAll — server broadcasts state_changed
  }

  Future<void> moveSession(int sessionId, int newTableId, int newSeat, int nowEpoch) async {
    await _service.moveSession(sessionId, newTableId, newSeat);
    await reloadAll(nowEpoch);
  }

  Future<void> addPayment(int playerId, int amount, int epoch) async {
    await _service.addPayment(playerId, amount, epoch);
    await fetchPlayers(epoch);
  }

  Future<void> startClubSession(int nowEpoch) async {
    final now = DateTime.fromMillisecondsSinceEpoch(nowEpoch * 1000);
    final defaultStart = DateTime(now.year, now.month, now.day, defaultSessionHour, defaultSessionMinute);
    final startEpoch = (defaultStart.millisecondsSinceEpoch / 1000).round();
    await _service.toggleClubState(true, startEpoch);
    isClubSessionOpen = true;
    clubSessionStartEpoch = startEpoch;
    notifyListeners();
  }

  Future<void> closeClubAndEndSessions(int stopEpoch) async {
    for (final s in sessions.where((s) => s.stopTime == null).toList()) {
      try {
        await _service.stopSession(s.sessionId, stopEpoch);
      } catch (e) {
        debugPrint('Warning: Failed to stop session ${s.sessionId} during club close.');
      }
    }
    await _service.toggleClubState(false, null);
    isClubSessionOpen = false;
    clubSessionStartEpoch = null;
    await reloadAll(stopEpoch);
  }

  Future<void> toggleTableStatus(int tableId, bool isActive, int nowEpoch) async {
    await _service.toggleTableStatus(tableId, isActive);
    await reloadAll(nowEpoch);
  }

  Future<void> updateDefaultSessionTime(int hour, int minute) async {
    await _service.updateDefaultSessionTime(hour, minute);
    await fetchState();
  }

  Future<void> setClockOffset(int offsetSeconds) async {
    await _service.setClockOffset(offsetSeconds);
    // Server broadcasts the new offset to all clients via WebSocket,
    // which updates TimeProvider through _subscribeToBroadcasts.
  }

  Future<void> triggerRemoteBackup() async {
    await _service.triggerRemoteBackup();
  }

  Future<void> reloadServerDatabase(int nowEpoch) async {
    await _service.reloadDatabase();
    await reloadAll(nowEpoch);
  }

  @override
  void dispose() {
    _broadcastSubscription?.cancel();
    super.dispose();
  }
}
