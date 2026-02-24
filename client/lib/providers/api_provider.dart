// client/lib/providers/api_provider.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'app_settings_provider.dart';
import '../models/poker_table.dart';
import '../models/player_selection_item.dart';
import '../models/session.dart';

class ApiProvider with ChangeNotifier {
  static const int httpOK = 200;
  final AppSettingsProvider _appSettingsProvider;

  bool _isConnected = false;
  bool _hasAttemptedAutoScan = false;

  // Volatile UI State for PlayerPanel
  int? _selectedPlayerId;

  List<PokerTable> _pokerTables = [];
  List<PlayerSelectionItem> _players = [];
  List<Session> _sessions = [];

  ApiProvider(this._appSettingsProvider) {
    reloadServerDatabase();
  }

  // --- Getters ---
  bool get isConnected => _isConnected;
  bool get hasAttemptedAutoScan => _hasAttemptedAutoScan;
  int? get selectedPlayerId => _selectedPlayerId;
  List<PokerTable> get pokerTables => _pokerTables;
  List<PlayerSelectionItem> get players => _players;
  List<Session> get sessions => _sessions;

  String get baseUrl =>
      'http://${_appSettingsProvider.currentSettings.serverIp}:${_appSettingsProvider.currentSettings.serverPort}';

  // --- UI Selection State ---
  void selectPlayer(int? playerId) {
    _selectedPlayerId = playerId;
    notifyListeners();
  }

  // --- Dashboard Data Getters ---

  List<Session> get displayedSessions {
    List<Session> filtered = _sessions;
    if (_selectedPlayerId != null) {
      filtered = filtered.where((s) => s.playerId == _selectedPlayerId).toList();
    }
    return filtered;
  }

  DateTime? get clubSessionStartDateTime {
    if (!isClubSessionOpen) return null;
    final now = DateTime.now();
    final settings = _appSettingsProvider.currentSettings;
    return DateTime(
      now.year, now.month, now.day,
      settings.defaultSessionHour,
      settings.defaultSessionMinute,
    );
  }

  // --- Business Logic: Dynamic Balance ---

  int getDynamicBalance(PlayerSelectionItem player) {
    final activeSession = _sessions.firstWhere(
      (s) => s.playerId == player.playerId && s.stopTime == null,
      orElse: () => Session(
        sessionId: -1,
        playerId: -1,
        startEpoch: 0,
        isPrepaid: false,
        prepayAmount: 0,
      ),
    );

    if (activeSession.sessionId == -1) {
      return player.balance;
    }

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final elapsedSeconds = now - activeSession.startEpoch;

    final int cost = ((elapsedSeconds * player.hourlyRate) / 3600.0).round();

    return player.balance - cost;
  }

  // --- Session State Logic ---

  bool get isClubSessionOpen {
    final now = DateTime.now();
    final settings = _appSettingsProvider.currentSettings;
    final sessionStart = DateTime(
      now.year, now.month, now.day,
      settings.defaultSessionHour,
      settings.defaultSessionMinute,
    );
    return now.isAfter(sessionStart);
  }

  Future<bool> toggleClubSession() async {
    final newState = !isClubSessionOpen;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/session'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _appSettingsProvider.currentSettings.localApiKey,
        },
        body: jsonEncode({'open': newState}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == httpOK) {
        await reloadServerDatabase();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // --- Data Fetching & Parsing ---

  Future<void> reloadServerDatabase() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/state'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _appSettingsProvider.currentSettings.localApiKey,
        },
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == httpOK) {
        _isConnected = true;
        final data = jsonDecode(response.body);

        if (data['tables'] != null) {
          _pokerTables = (data['tables'] as List).map((t) => PokerTable.fromMap(t)).toList();
        }
        if (data['players'] != null) {
          _players = (data['players'] as List).map((p) => PlayerSelectionItem.fromMap(p)).toList();
        }
        if (data['sessions'] != null) {
          _sessions = (data['sessions'] as List).map((s) => Session.fromMap(s)).toList();
        }
      } else {
        _isConnected = false;
      }
    } catch (_) {
      _isConnected = false;
    }
    notifyListeners();
  }

  Future<void> addSession(Session session) async {
    await http.post(
      Uri.parse('$baseUrl/sessions'),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': _appSettingsProvider.currentSettings.localApiKey
      },
      body: jsonEncode(session.toMap()),
    );
    await reloadServerDatabase();
  }

  Future<void> stopSession(int sessionId, int stopEpoch) async {
    await http.put(
      Uri.parse('$baseUrl/sessions/$sessionId/stop'),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': _appSettingsProvider.currentSettings.localApiKey,
      },
      body: jsonEncode({'stopEpoch': stopEpoch}),
    );
    await reloadServerDatabase();
  }

  Future<void> addPayment({required int playerId, required double amount}) async {
    await http.post(
      Uri.parse('$baseUrl/payments'),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': _appSettingsProvider.currentSettings.localApiKey
      },
      body: jsonEncode({'playerId': playerId, 'amount': amount}),
    );
  }

  Future<void> fetchPlayers() => reloadServerDatabase();
  Future<void> fetchSessions() => reloadServerDatabase();

  void markAutoScanAttempted() {
    _hasAttemptedAutoScan = true;
    notifyListeners();
  }
}