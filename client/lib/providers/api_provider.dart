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

  // Alias for UI components expecting .tables
  List<PokerTable> get tables => pokerTables;

  int? selectedPlayerId;
  bool isClubSessionOpen = false;
  DateTime? clubSessionStartDateTime;
  Duration _timeOffset = Duration.zero;

  ApiProvider(this.settings);

  void updateTimeOffset(Duration offset) {
    if (_timeOffset != offset) {
      _timeOffset = offset;
      notifyListeners();
    }
  }

  /// Returns balance in integer dollars
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
        // Calculate cost and round to nearest dollar
        final double cost = (elapsedSeconds * player.hourlyRate) / 3600;
        currentBalance -= cost.round();
      }
    }
    return currentBalance;
  }

  // --- UI Actions ---

  void selectPlayer(int? playerId) {
    selectedPlayerId = playerId;
    notifyListeners();
  }

  List<Session> get displayedSessions {
    if (selectedPlayerId != null) {
      return sessions.where((s) => s.playerId == selectedPlayerId).toList();
    }
    return sessions;
  }

  List<int> getOccupiedSeatsForTable(int tableId) {
    return sessions
        .where((s) => s.pokerTableId == tableId && s.stopTime == null)
        .map((s) => s.seatNumber ?? 0)
        .toList();
  }

  // --- API Implementation ---

  String get _baseUrl => "http://${settings.serverIp}:${settings.serverPort}";
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'x-api-key': settings.localApiKey,
  };

  Future<void> fetchPlayers() async {
    final res = await http.get(Uri.parse("$_baseUrl/players"), headers: _headers);
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      players = data.map((json) => PlayerSelectionItem.fromJson(json)).toList();
      notifyListeners();
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
    final res = await http.get(Uri.parse("$_baseUrl/sessions"), headers: _headers);
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      sessions = data.map((json) => Session.fromJson(json)).toList();
      notifyListeners();
    }
  }

  Future<void> addSession(Session session) async {
    await http.post(Uri.parse("$_baseUrl/sessions"), headers: _headers, body: jsonEncode(session.toJson()));
    await reloadAll();
  }

  Future<void> stopSession(int sessionId, int stopEpoch) async {
    await http.post(Uri.parse("$_baseUrl/sessions/$sessionId/stop"), headers: _headers, body: jsonEncode({'stopEpoch': stopEpoch}));
    await reloadAll();
  }

  // FIXED: Positional arguments to match player_selection_panel.dart
  Future<void> addPayment(int playerId, int amount) async {
    await http.post(
      Uri.parse("$_baseUrl/players/$playerId/payments"),
      headers: _headers,
      body: jsonEncode({'amount': amount}),
    );
    await fetchPlayers();
  }

  Future<void> startClubSession(int startEpoch) async {
    await http.post(Uri.parse("$_baseUrl/club/start"), headers: _headers, body: jsonEncode({'startEpoch': startEpoch}));
    isClubSessionOpen = true;
    notifyListeners();
  }

  Future<void> stopClubSession() async {
    await http.post(Uri.parse("$_baseUrl/club/stop"), headers: _headers);
    isClubSessionOpen = false;
    notifyListeners();
  }

  Future<void> reloadServerDatabase() async {
    await http.post(Uri.parse("$_baseUrl/system/reload"), headers: _headers);
    await reloadAll();
  }

  Future<void> reloadAll() async {
    await fetchTables();
    await fetchPlayers();
    await fetchSessions();
  }
}