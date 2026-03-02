// client/lib/providers/api_provider.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/app_settings.dart';
import '../models/player_selection_item.dart';
import '../models/session.dart';
import '../models/poker_table.dart';

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
      print(x);
    }
  }

  int getDynamicBalance(PlayerSelectionItem player, int nowEpoch) {
    int currentBalance = player.balance;

    final activeSessions = sessions.where((s) =>
      s.playerId == player.playerId && s.stopTime == null
    );

    for (var session in activeSessions) {
      // THE FIX: Prepaid sessions do NOT incur hourly ticking costs.
      // Their costs are already locked and deducted by the DB.
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
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        isClubSessionOpen = data['Is_Club_Open'] == 1;
        clubSessionStartEpoch = data['Club_Start_Epoch'];
        defaultSessionHour = data['Default_Session_Hour'] ?? settings.defaultSessionHour;
        defaultSessionMinute = data['Default_Session_Minute'] ?? settings.defaultSessionMinute;
        notifyListeners();
      }
    } catch (e) {
      print("🛑 ERROR [ApiProvider - fetchState]: $e");
    }
  }

  Future<void> fetchPlayers() async {
    final String url = "$_baseUrl/players/selection";
    try {
      final res = await http.get(Uri.parse(url), headers: _headers);
      if (res.statusCode == 200) {
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
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      pokerTables = data.map((json) => PokerTable.fromJson(json)).toList();
      notifyListeners();
    }
  }

  Future<void> fetchSessions() async {
    final String url = "$_baseUrl/sessions/panel";
    try {
      final res = await http.get(Uri.parse(url), headers: _headers);
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        sessions = data.map((json) => Session.fromJson(json)).toList();
        notifyListeners();
      }
    } catch (e) {
      print("🛑 ERROR [ApiProvider - fetchSessions]: $e");
    }
  }

  Future<void> addSession(Session session) async {
    await http.post(Uri.parse("$_baseUrl/sessions"), headers: _headers, body: jsonEncode(session.toJson()));
    await reloadAll();
  }

  Future<void> stopSession(int sessionId, int stopEpoch) async {
    await http.post(Uri.parse("$_baseUrl/sessions/stop"), headers: _headers, body: jsonEncode({
      'Session_Id': sessionId,
      'Stop_Epoch': stopEpoch
    }));
    await reloadAll();
  }

  Future<void> moveSession(int sessionId, int newTableId, int newSeat) async {
    await http.post(
      Uri.parse("$_baseUrl/sessions/move"),
      headers: _headers,
      body: jsonEncode({
        'Session_Id': sessionId,
        'PokerTable_Id': newTableId,
        'Seat_Number': newSeat,
      }),
    );
    await reloadAll();
  }

  Future<void> addPayment(int playerId, int amount, int epoch) async {
    await http.post(
      Uri.parse("$_baseUrl/payments"),
      headers: _headers,
      body: jsonEncode({
        'Player_Id': playerId,
        'Amount': amount,
        'Epoch': epoch
      }),
    );
    await fetchPlayers();
  }

  Future<void> startClubSession(int nowEpoch) async {
    final now = DateTime.fromMillisecondsSinceEpoch(nowEpoch * 1000);
    final defaultStart = DateTime(now.year, now.month, now.day, defaultSessionHour, defaultSessionMinute);
    final startEpoch = (defaultStart.millisecondsSinceEpoch / 1000).round();

    await http.post(Uri.parse("$_baseUrl/state/toggle"), headers: _headers, body: jsonEncode({
      'Is_Club_Open': true,
      'Club_Start_Epoch': startEpoch
    }));

    isClubSessionOpen = true;
    clubSessionStartEpoch = startEpoch;
    notifyListeners();
  }

  Future<void> closeClubAndEndSessions(int stopEpoch) async {
    final activeSessions = sessions.where((s) => s.stopTime == null).toList();
    for (var s in activeSessions) {
      await http.post(Uri.parse("$_baseUrl/sessions/stop"), headers: _headers, body: jsonEncode({
        'Session_Id': s.sessionId,
        'Stop_Epoch': stopEpoch
      }));
    }

    await http.post(Uri.parse("$_baseUrl/state/toggle"), headers: _headers, body: jsonEncode({
      'Is_Club_Open': false,
      'Club_Start_Epoch': null
    }));

    isClubSessionOpen = false;
    clubSessionStartEpoch = null;
    await reloadAll();
  }

  Future<void> toggleTableStatus(int tableId, bool isActive) async {
    await http.post(
      Uri.parse("$_baseUrl/tables/toggle"),
      headers: _headers,
      body: jsonEncode({
        'PokerTable_Id': tableId,
        'IsActive': isActive,
      }),
    );
    await reloadAll();
  }

  Future<void> updateDefaultSessionTime(int hour, int minute) async {
    await http.post(
      Uri.parse("$_baseUrl/state/defaults"),
      headers: _headers,
      body: jsonEncode({
        'hour': hour,
        'minute': minute
      }),
    );
    await fetchState();
  }

  Future<void> triggerRemoteBackup() async {
    final res = await http.post(
      Uri.parse("$_baseUrl/maintenance/backup"),
      headers: _headers,
      body: jsonEncode({'apiKey': settings.localApiKey}),
    );

    if (res.statusCode != 200) {
      throw Exception('Server rejected backup. Check API Key. Status: ${res.statusCode}');
    }
  }

  Future<void> reloadServerDatabase() async {
    await http.post(Uri.parse("$_baseUrl/system/reload"), headers: _headers);
    await reloadAll();
  }

  Future<void> reloadAll() async {
    await fetchState();
    await fetchTables();
    await fetchPlayers();
    await fetchSessions();
  }
}