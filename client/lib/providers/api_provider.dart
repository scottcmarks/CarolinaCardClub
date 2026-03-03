// client/lib/providers/api_provider.dart

import 'dart:convert';
import 'package:flutter/foundation.dart'; // <-- Required for debugPrint
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/app_settings.dart';
import '../models/player_selection_item.dart';
import '../models/session.dart';
import '../models/poker_table.dart';
import 'package:shared/shared.dart';

class ApiProvider with ChangeNotifier {
  final AppSettings settings;

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

  bool debugFetchPlayers = false;

  ApiProvider(this.settings);

  void debugPrintFetchPlayers(String x) {
    if (debugFetchPlayers) {
      debugPrint(x); // Swapped print for debugPrint
    }
  }

  int getDynamicBalance(PlayerSelectionItem player, int nowEpoch) {
    int currentBalance = player.balance;

    final activeSessions = sessions.where((s) =>
      s.playerId == player.playerId && s.stopTime == null
    );

    for (var session in activeSessions) {
      if (!session.isPrepaid) {
        final elapsedSeconds = nowEpoch - session.startEpoch;
        if (elapsedSeconds > 0) {
          final double cost = (elapsedSeconds * session.hourlyRate) / 3600;
          currentBalance -= cost.round();
        }
      }
    }
    return currentBalance;
  }

  void selectPlayer(int? playerId) {
    selectedPlayerId = playerId;
    notifyListeners();
  }

  List<Session> get displayedSessions {
    Iterable<Session> filtered = sessions;

    if (isClubSessionOpen) {
      filtered = filtered.where((s) => s.stopTime == null);
    }

    if (selectedPlayerId != null) {
      filtered = filtered.where((s) => s.playerId == selectedPlayerId);
    }

    final sortedList = filtered.toList();
    sortedList.sort((a, b) => b.startEpoch.compareTo(a.startEpoch));

    return sortedList;
  }

  Map<int, String> getOccupiedSeatsAndNamesForTable(int tableId, {int? seatingPlayerId}) {
    final Map<int, String> occupied = {};

    final activeSessions = sessions.where((s) => s.pokerTableId == tableId && s.stopTime == null);
    for (var s in activeSessions) {
      if (s.seatNumber != null) {
        occupied[s.seatNumber!] = s.name;
      }
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
          s.stopTime != null
        );
      }

      final table = pokerTables.firstWhere((t) => t.pokerTableId == tableId);
      final otherSeatsCapacity = table.capacity - 1;
      final occupiedOtherSeats = occupied.keys.where((seat) => seat != fmSeat).length;
      bool allOtherSeatsTaken = occupiedOtherSeats >= otherSeatsCapacity;

      if (!(fmHasClosedSession && allOtherSeatsTaken)) {
        if (!occupied.containsKey(fmSeat)) {
          occupied[fmSeat] = "Reserved";
        }
      }
    }

    return occupied;
  }

  String get _baseUrl => "http://${settings.serverIp}:${settings.serverPort}";
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'x-api-key': settings.localApiKey,
  };

  Future<void> fetchState() async {
    try {
      final res = await http.get(Uri.parse("$_baseUrl/state"), headers: _headers);
      if (res.statusCode == Shared.httpOK) {
        final data = jsonDecode(res.body);
        isClubSessionOpen = data['Is_Club_Open'] == 1;
        clubSessionStartEpoch = data['Club_Start_Epoch'];
        defaultSessionHour = data['Default_Session_Hour'] ?? settings.defaultSessionHour;
        defaultSessionMinute = data['Default_Session_Minute'] ?? settings.defaultSessionMinute;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("🛑 ERROR [ApiProvider - fetchState]: $e");
    }
  }

  Future<void> fetchPlayers(int nowEpoch) async {
    final String url = "$_baseUrl/players/selection?epoch=$nowEpoch";
    try {
      final res = await http.get(Uri.parse(url), headers: _headers);
      if (res.statusCode == Shared.httpOK) {
        final List data = jsonDecode(res.body);
        players = data.map((json) {
          try {
            return PlayerSelectionItem.fromJson(json);
          } catch (e) {
            return PlayerSelectionItem(playerId: -1, name: "Parse Error ($e)", balance: 0, hourlyRate: 0.0, prepayHours: 0, isActive: false);
          }
        }).toList();

        players.removeWhere((p) => p.playerId == -1);
        notifyListeners();
      }
    } catch (e) {
      debugPrintFetchPlayers("🛑 ERROR [ApiProvider]: Network or execution exception: $e");
    }
  }

  Future<void> fetchTables() async {
    final res = await http.get(Uri.parse("$_baseUrl/tables"), headers: _headers);
    if (res.statusCode == Shared.httpOK) {
      final List data = jsonDecode(res.body);
      pokerTables = data.map((json) => PokerTable.fromJson(json)).toList();
      notifyListeners();
    }
  }

  Future<void> fetchSessions() async {
    final String url = "$_baseUrl/sessions/panel";
    try {
      final res = await http.get(Uri.parse(url), headers: _headers);
      if (res.statusCode == Shared.httpOK) {
        final List data = jsonDecode(res.body);
        sessions = data.map((json) => Session.fromJson(json)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("🛑 ERROR [ApiProvider - fetchSessions]: $e");
    }
  }

  Future<void> addSession(Session session, int nowEpoch) async {
    final res = await http.post(Uri.parse("$_baseUrl/sessions"), headers: _headers, body: jsonEncode(session.toJson()));
    if (res.statusCode != Shared.httpOK) {
      final error = jsonDecode(res.body)['error'] ?? 'Failed to add session';
      throw Exception(error);
    }
    await reloadAll(nowEpoch);
  }

  Future<void> stopSession(int sessionId, int stopEpoch) async {
    final res = await http.post(Uri.parse("$_baseUrl/sessions/stop"), headers: _headers, body: jsonEncode({
      'Session_Id': sessionId,
      'Stop_Epoch': stopEpoch
    }));
    if (res.statusCode != Shared.httpOK) {
      final error = jsonDecode(res.body)['error'] ?? 'Failed to stop session';
      throw Exception(error);
    }
    await reloadAll(stopEpoch);
  }

  Future<void> moveSession(int sessionId, int newTableId, int newSeat, int nowEpoch) async {
    final res = await http.post(
      Uri.parse("$_baseUrl/sessions/move"),
      headers: _headers,
      body: jsonEncode({
        'Session_Id': sessionId,
        'PokerTable_Id': newTableId,
        'Seat_Number': newSeat,
      }),
    );
    if (res.statusCode != Shared.httpOK) {
      final error = jsonDecode(res.body)['error'] ?? 'Failed to move session';
      throw Exception(error);
    }
    await reloadAll(nowEpoch);
  }

  Future<void> addPayment(int playerId, int amount, int epoch) async {
    final res = await http.post(
      Uri.parse("$_baseUrl/payments"),
      headers: _headers,
      body: jsonEncode({
        'Player_Id': playerId,
        'Amount': amount,
        'Epoch': epoch
      }),
    );
    if (res.statusCode != Shared.httpOK) {
      final error = jsonDecode(res.body)['error'] ?? 'Failed to process payment';
      throw Exception(error);
    }
    await fetchPlayers(epoch);
  }

  Future<void> startClubSession(int nowEpoch) async {
    final now = DateTime.fromMillisecondsSinceEpoch(nowEpoch * 1000);
    final defaultStart = DateTime(now.year, now.month, now.day, defaultSessionHour, defaultSessionMinute);
    final startEpoch = (defaultStart.millisecondsSinceEpoch / 1000).round();

    final res = await http.post(Uri.parse("$_baseUrl/state/toggle"), headers: _headers, body: jsonEncode({
      'Is_Club_Open': true,
      'Club_Start_Epoch': startEpoch
    }));

    if (res.statusCode != Shared.httpOK) {
      throw Exception('Failed to start club session');
    }

    isClubSessionOpen = true;
    clubSessionStartEpoch = startEpoch;
    notifyListeners();
  }

  Future<void> closeClubAndEndSessions(int stopEpoch) async {
    final activeSessions = sessions.where((s) => s.stopTime == null).toList();
    for (var s in activeSessions) {
      final res = await http.post(Uri.parse("$_baseUrl/sessions/stop"), headers: _headers, body: jsonEncode({
        'Session_Id': s.sessionId,
        'Stop_Epoch': stopEpoch
      }));
      if (res.statusCode != Shared.httpOK) {
        debugPrint("Warning: Failed to stop session ${s.sessionId} during club close.");
      }
    }

    final res = await http.post(Uri.parse("$_baseUrl/state/toggle"), headers: _headers, body: jsonEncode({
      'Is_Club_Open': false,
      'Club_Start_Epoch': null
    }));

    if (res.statusCode != Shared.httpOK) {
      throw Exception('Failed to toggle club state off');
    }

    isClubSessionOpen = false;
    clubSessionStartEpoch = null;
    await reloadAll(stopEpoch);
  }

  Future<void> toggleTableStatus(int tableId, bool isActive, int nowEpoch) async {
    final res = await http.post(
      Uri.parse("$_baseUrl/tables/toggle"),
      headers: _headers,
      body: jsonEncode({
        'PokerTable_Id': tableId,
        'IsActive': isActive,
      }),
    );
    if (res.statusCode != Shared.httpOK) {
      throw Exception('Failed to toggle table status');
    }
    await reloadAll(nowEpoch);
  }

  Future<void> updateDefaultSessionTime(int hour, int minute) async {
    final res = await http.post(
      Uri.parse("$_baseUrl/state/defaults"),
      headers: _headers,
      body: jsonEncode({
        'hour': hour,
        'minute': minute
      }),
    );
    if (res.statusCode != Shared.httpOK) {
      throw Exception('Failed to update default session time');
    }
    await fetchState();
  }

  Future<void> triggerRemoteBackup() async {
    final res = await http.post(
      Uri.parse("$_baseUrl/maintenance/backup"),
      headers: _headers,
      body: jsonEncode({'apiKey': settings.localApiKey}),
    );

    if (res.statusCode != Shared.httpOK) {
      throw Exception('Server rejected backup. Check API Key. Status: ${res.statusCode}');
    }
  }

  Future<void> reloadServerDatabase(int nowEpoch) async {
    final res = await http.post(Uri.parse("$_baseUrl/system/reload"), headers: _headers);
    if (res.statusCode != Shared.httpOK) {
      throw Exception('Failed to reload server database');
    }
    await reloadAll(nowEpoch);
  }

  Future<void> reloadAll(int nowEpoch) async {
    await fetchState();
    await fetchTables();
    await fetchPlayers(nowEpoch);
    await fetchSessions();
  }
}