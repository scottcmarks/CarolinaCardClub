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
  DateTime? clubSessionStartDateTime;
  Duration _timeOffset = Duration.zero;

  bool debugFetchPlayers = false;

  ApiProvider(this.settings);

  void debugPrintFetchPlayers(String x) {
    if (debugFetchPlayers) {
      print(x);
    }
  }

  void updateTimeOffset(Duration offset) {
    if (_timeOffset != offset) {
      _timeOffset = offset;
      notifyListeners();
    }
  }

  int getDynamicBalance(PlayerSelectionItem player) {
    int currentBalance = player.balance;

    final gameNow = DateTime.now().add(_timeOffset);
    final nowEpoch = (gameNow.millisecondsSinceEpoch / 1000).round();

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

    return filtered.toList();
  }

  // UPDATED: Now accepts the player ID to conditionally block the FM seat
  List<int> getOccupiedSeatsForTable(int tableId, {int? seatingPlayerId}) {
    final occupied = sessions
        .where((s) => s.pokerTableId == tableId && s.stopTime == null)
        .map((s) => s.seatNumber ?? 0)
        .toList();

    // FM Seat Protection Logic
    if (seatingPlayerId != null &&
        seatingPlayerId != settings.floorManagerPlayerId &&
        tableId == settings.floorManagerReservedTable) {

      final fmSeat = settings.floorManagerReservedSeat;

      // 1. Check if FM has a closed session in the *current* club session
      bool fmHasClosedSession = false;
      if (clubSessionStartDateTime != null) {
        final clubStartEpoch = (clubSessionStartDateTime!.millisecondsSinceEpoch ~/ 1000);
        fmHasClosedSession = sessions.any((s) =>
          s.playerId == settings.floorManagerPlayerId &&
          s.startEpoch >= clubStartEpoch &&
          s.stopTime != null
        );
      }

      // 2. Check if all other seats are taken
      final table = pokerTables.firstWhere((t) => t.pokerTableId == tableId);
      final otherSeatsCapacity = table.capacity - 1; // Capacity minus the FM seat
      final occupiedOtherSeats = occupied.where((seat) => seat != fmSeat).length;
      bool allOtherSeatsTaken = occupiedOtherSeats >= otherSeatsCapacity;

      // 3. Block the seat if conditions are NOT met
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

  // ADDED: Fetch State to sync club bounds on startup
  Future<void> fetchState() async {
    try {
      final res = await http.get(Uri.parse("$_baseUrl/state"), headers: _headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        isClubSessionOpen = data['Is_Club_Open'] == 1;
        if (data['Club_Start_Epoch'] != null) {
          clubSessionStartDateTime = DateTime.fromMillisecondsSinceEpoch(data['Club_Start_Epoch'] * 1000);
        } else {
          clubSessionStartDateTime = null;
        }
        notifyListeners();
      }
    } catch (e) {
      print("🛑 ERROR [ApiProvider - fetchState]: $e");
    }
  }

  Future<void> fetchPlayers() async {
    final String url = "$_baseUrl/players/selection";

    debugPrintFetchPlayers("🐞 DEBUG [ApiProvider]: Fetching players from $url");

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

  Future<void> addPayment(int playerId, int amount) async {
    await http.post(
      Uri.parse("$_baseUrl/payments"),
      headers: _headers,
      body: jsonEncode({
        'Player_Id': playerId,
        'Amount': amount
      }),
    );
    await fetchPlayers();
  }

  Future<void> startClubSession(int startEpoch) async {
    await http.post(Uri.parse("$_baseUrl/state/toggle"), headers: _headers, body: jsonEncode({
      'Is_Club_Open': true,
      'Club_Start_Epoch': startEpoch
    }));
    isClubSessionOpen = true;
    clubSessionStartDateTime = DateTime.fromMillisecondsSinceEpoch(startEpoch * 1000);
    notifyListeners();
  }

  Future<void> closeClubAndEndSessions() async {
    final int stopEpoch = (DateTime.now().add(_timeOffset).millisecondsSinceEpoch ~/ 1000);

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
    clubSessionStartDateTime = null;
    await reloadAll();
  }

  Future<void> stopClubSession() async {
    await http.post(Uri.parse("$_baseUrl/state/toggle"), headers: _headers, body: jsonEncode({
      'Is_Club_Open': false,
      'Club_Start_Epoch': null
    }));
    isClubSessionOpen = false;
    clubSessionStartDateTime = null;
    notifyListeners();
  }

  Future<void> reloadServerDatabase() async {
    await http.post(Uri.parse("$_baseUrl/system/reload"), headers: _headers);
    await reloadAll();
  }

  Future<void> reloadAll() async {
    await fetchState(); // Always sync state first
    await fetchTables();
    await fetchPlayers();
    await fetchSessions();
  }
}