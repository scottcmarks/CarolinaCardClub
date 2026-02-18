// client/lib/providers/api_provider.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared/shared.dart';

import '../models/session.dart';
import '../models/session_panel_item.dart';
import '../models/player_selection_item.dart';
import '../models/poker_table.dart';
import 'app_settings_provider.dart';

class ApiProvider with ChangeNotifier {
  final AppSettingsProvider _appSettingsProvider;

  List<SessionPanelItem> _sessions = [];
  List<PlayerSelectionItem> _players = [];
  List<PokerTable> _pokerTables = [];

  // Track selection state for the Dashboard
  int? _selectedPlayerId;

  bool isClubSessionOpen = false;
  DateTime? clubSessionStartDateTime;

  bool _isConnected = false;
  String? _lastError;

  ApiProvider(this._appSettingsProvider) {
    reloadServerDatabase();
  }

  // --- GETTERS ---
  List<PlayerSelectionItem> get players => _players;
  List<PokerTable> get pokerTables => _pokerTables;
  bool get isConnected => _isConnected;
  String? get lastError => _lastError;
  int? get selectedPlayerId => _selectedPlayerId;

  // --- THE 4-STATE DASHBOARD LOGIC ---
  List<SessionPanelItem> get displayedSessions {
    Iterable<SessionPanelItem> filtered = _sessions;

    if (isClubSessionOpen) {
      // MODE A: ACTIVE FLOOR (Club is Open)
      // Rule: Show only sessions that are currently running (stopTime is null)
      filtered = filtered.where((s) => s.stopTime == null);
    } else {
      // MODE B: HISTORY (Club is Closed)
      // Rule: Show everything (Recorded History)
    }

    // SELECTION FILTER (Applies to both modes)
    if (_selectedPlayerId != null) {
      filtered = filtered.where((s) => s.playerId == _selectedPlayerId);
    }

    // Sort: Newest first so active/recent stuff is at the top
    var list = filtered.toList();
    list.sort((a, b) => b.startTime.compareTo(a.startTime));
    return list;
  }

  // --- ACTIONS ---

  void selectPlayer(int? playerId) {
    _selectedPlayerId = playerId;
    notifyListeners();
  }

  void toggleClubSession() {
    isClubSessionOpen = !isClubSessionOpen;
    if (isClubSessionOpen) {
      final now = DateTime.now();
      final settings = _appSettingsProvider.currentSettings;
      clubSessionStartDateTime = DateTime(
        now.year, now.month, now.day,
        settings.defaultSessionHour,
        settings.defaultSessionMinute
      );
    } else {
      clubSessionStartDateTime = null;
    }
    notifyListeners();
  }

  Future<void> retryConnection() async {
    await reloadServerDatabase();
  }

  // --- DATA FETCHING ---

  Future<void> reloadServerDatabase() async {
    _lastError = null;
    try {
      // 1. Fetch Players
      final pRes = await http.get(Uri.parse('$_baseUrl/players/selection'), headers: _headers);
      if (pRes.statusCode == 200) {
        final List<dynamic> rawList = json.decode(pRes.body);
        _players = [];
        for (var item in rawList) {
          try {
            _players.add(PlayerSelectionItem.fromMap(item));
          } catch (e) {
            print("🛑 Player Data Error: $e");
          }
        }
      }

      // 2. Fetch Sessions
      final sRes = await http.get(Uri.parse('$_baseUrl/sessions/panel'), headers: _headers);
      if (sRes.statusCode == 200) {
        final List<dynamic> rawList = json.decode(sRes.body);
        _sessions = [];
        for (var item in rawList) {
          try {
            // Load ALL sessions. The smart getter 'displayedSessions' filters them later.
            _sessions.add(SessionPanelItem.fromMap(item));
          } catch (e) {
            print("🛑 Session Data Error: $e");
          }
        }
      }

      // 3. Init Tables (Default)
       if (_pokerTables.isEmpty) {
        _pokerTables = [
          PokerTable(pokerTableId: 1, name: "Table 1", capacity: 9, isActive: true),
          PokerTable(pokerTableId: 2, name: "Table 2", capacity: 10, isActive: true),
        ];
      }

      _isConnected = true;
      notifyListeners();
    } catch (e) {
      _isConnected = false;
      _lastError = e.toString();
      notifyListeners();
    }
  }

  // Helper Getters
  String get _baseUrl => 'http://${_appSettingsProvider.currentSettings.serverIp}:${_appSettingsProvider.currentSettings.serverPort}';
  Map<String, String> get _headers => {'Content-Type': 'application/json', 'x-api-key': _appSettingsProvider.currentSettings.localApiKey};

  // Helper: Get Balance
  int getDynamicBalance({required int playerId, required DateTime currentTime}) {
     final p = _players.firstWhere(
      (p) => p.playerId == playerId,
      orElse: () => PlayerSelectionItem(
        playerId: -1, name: "Unknown", balance: 0, hourlyRate: 0.0, prepayHours: 0, isActive: false
      )
    );
    int runningBalance = p.balance;
    for (var s in _sessions) {
      // FIX: This was the broken line. Now complete:
      if (s.playerId == playerId && s.stopTime == null) {
        Duration diff = currentTime.difference(s.startTime);
        if (diff.isNegative) diff = Duration.zero;
        double rawCost = s.isPrepaid
            ? s.prepayAmount.toDouble()
            : (diff.inSeconds / Shared.secondsPerHour * s.rate);
        runningBalance -= rawCost.round();
      }
    }
    return runningBalance;
  }

  Future<void> addSession(Session session) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/sessions'),
      headers: _headers,
      body: json.encode(session.toMap())
    );
    if (response.statusCode != 200) throw Exception("Failed to add session");
    await reloadServerDatabase();
  }

  Future<void> triggerRemoteBackup(String apiKey) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/maintenance/backup'),
      headers: _headers,
      body: json.encode({'apiKey': apiKey})
    );
    if (response.statusCode != 200) throw Exception("Backup Failed");
  }

  Future<void> triggerRemoteRestore(String apiKey) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/maintenance/restore'),
      headers: _headers,
      body: json.encode({'apiKey': apiKey})
    );
    if (response.statusCode != 200) throw Exception("Restore Failed");
    await reloadServerDatabase();
  }
}