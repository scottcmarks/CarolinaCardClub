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

  int? selectedPlayerId;
  bool isClubSessionOpen = false;

  int? clubSessionStartEpoch;
  int defaultSessionHour = 19;
  int defaultSessionMinute = 30;

  bool debugFetchPlayers = false;

  ApiProvider(this.settings);

  void debugPrintFetchPlayers(String x) {
    if (debugFetchPlayers) {
      print(x);
    }
  }

  // UPDATED SIGNATURE
  int getDynamicBalance(PlayerSelectionItem player, int nowEpoch) {
    int currentBalance = player.balance;

    final activeSessions = sessions.where((s) =>
      s.playerId == player.playerId && s.stopTime == null
    );

    for (var session in activeSessions) {
      final elapsedSeconds = nowEpoch - session.startEpoch;
      if (elapsedSeconds > 0) {
        final double cost = (elapsedSeconds * player.hourlyRate) / 3600;
        currentBalance -= cost.round();
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

  List<int> getOccupiedSeatsForTable(int tableId, {int? seatingPlayerId}) {
    final occupied = sessions
        .where((s) => s.pokerTableId == tableId && s.stopTime == null)
        .map((s) => s.seatNumber ?? 0)
        .toList();

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
      final occupiedOtherSeats = occupied.where((seat) => seat != fmSeat).length;
      bool allOtherSeatsTaken = occupiedOtherSeats >= otherSeatsCapacity;

      if (!(fmHasClosedSession && allOtherSeatsTaken)) {
        if (!occupied.contains(fmSeat)) {
          occupied.add(fmSeat);
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
        defaultSessionHour = data['Default_Session_Hour'] ?? 19;
        defaultSessionMinute = data['Default_Session_Minute'] ?? 30;

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
            return PlayerSelectionItem(playerId: -1, name: "Parse Error ($e)", balance: 0);
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

  // UPDATED SIGNATURE
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

  // UPDATED SIGNATURE
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

  // UPDATED SIGNATURE
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