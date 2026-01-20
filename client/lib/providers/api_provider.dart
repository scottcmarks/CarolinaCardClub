// client/lib/providers/api_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';

import '../logic/balance_calculator.dart';
import '../models/player_selection_item.dart';
import '../models/session.dart';
import '../models/session_panel_item.dart';
import '../services/socket_client.dart';
import 'app_settings_provider.dart';

export '../services/socket_client.dart' show ConnectionStatus;

class ApiProvider with ChangeNotifier {
  AppSettingsProvider _appSettingsProvider;
  final SocketClient _socketClient = SocketClient();

  List<PlayerSelectionItem> _players = [];
  List<SessionPanelItem> _sessions = [];
  int? _lastSessionPlayerIdFilter;
  bool _lastSessionActiveOnlyFilter = false;

  bool _mounted = true;
  String? _currentConnectionUrl;

  bool _hasAttemptedAutoScan = false;
  bool get hasAttemptedAutoScan => _hasAttemptedAutoScan;

  List<PlayerSelectionItem> get players => _players;
  List<SessionPanelItem> get sessions => _sessions;
  ConnectionStatus get connectionStatus => _socketClient.status;
  String? get lastError => _socketClient.lastError;
  String? get connectingUrl => _currentConnectionUrl;

  Future<void> connectionFuture = Completer<void>().future;

  ApiProvider(this._appSettingsProvider) {
    _currentConnectionUrl = _appSettingsProvider.currentSettings.localServerUrl;

    _socketClient.statusNotifier.addListener(() {
      _safeNotifyListeners();
    });

    _socketClient.onBroadcast.listen((message) {
      if (message['event'] == 'update') {
        // **FIX**: Catch errors here too so broadcast updates don't crash the app
        _fetchAllData().catchError((e) {
          debugPrint('ApiProvider: Failed to update data from broadcast: $e');
        });
      }
    });
  }

  void initialize() {
    if (connectionStatus == ConnectionStatus.connecting ||
        connectionStatus == ConnectionStatus.connected) {
      return;
    }

    _hasAttemptedAutoScan = false;
    connectionFuture = connect();
  }

  Future<void> connect() async {
    _currentConnectionUrl = _appSettingsProvider.currentSettings.localServerUrl;
    final apiKey = _appSettingsProvider.currentSettings.localServerApiKey;

    // 1. Establish Socket Connection
    await _socketClient.connect(_currentConnectionUrl!, apiKey);

    // 2. If successful, fetch initial data immediately
    if (connectionStatus == ConnectionStatus.connected) {
      debugPrint('ApiProvider: Connection successful. Fetching initial data...');
      try {
        await _fetchAllData();
      } catch (e) {
        debugPrint('ApiProvider: Error fetching initial data: $e');
        // **FIX**: If we can't get data, the connection is useless.
        // Disconnect so the UI shows the "Connection Failed" screen again.
        await _socketClient.disconnect();
      }
    }
  }

  Future<void> _fetchAllData() async {
    // We await these so any errors (like Timeout) bubble up to be caught
    await fetchPlayerSelectionList();
    await fetchSessionPanelList(
      playerId: _lastSessionPlayerIdFilter,
      onlyActive: _lastSessionActiveOnlyFilter,
    );
  }

  void markAutoScanAttempted() {
    _hasAttemptedAutoScan = true;
    notifyListeners();
  }

  Future<void> updateServerUrl(String newUrl) async {
    debugPrint('ApiProvider: Updating URL to $newUrl and saving settings.');
    final newSettings = _appSettingsProvider.currentSettings.copyWith(
      localServerUrl: newUrl
    );
    await _appSettingsProvider.updateSettings(newSettings);
    _currentConnectionUrl = newUrl;
    notifyListeners();
  }

  Future<void> disconnect() async {
    await _socketClient.disconnect();
  }

  void retryConnection() {
    _hasAttemptedAutoScan = false;
    initialize();
  }

  void updateAppSettings(AppSettingsProvider newSettingsProvider) {
    final newUrl = newSettingsProvider.currentSettings.localServerUrl;
    if (_currentConnectionUrl != newUrl) {
      _appSettingsProvider = newSettingsProvider;
      _currentConnectionUrl = newUrl;
      retryConnection();
    } else {
      _appSettingsProvider = newSettingsProvider;
    }
  }

  // --- Logic Delegates ---
  double getDynamicBalance({
    required int playerId,
    required DateTime currentTime,
    required DateTime? clubSessionStartDateTime,
  }) {
    return BalanceCalculator.getDynamicBalance(
      playerId: playerId,
      currentTime: currentTime,
      clubSessionStartDateTime: clubSessionStartDateTime,
      players: _players,
      sessions: _sessions,
    );
  }

  // --- Command Methods ---
  Future<dynamic> _sendCommand(String command,
      [Map<String, dynamic>? params]) async {
    final apiKey = _appSettingsProvider.currentSettings.localServerApiKey;
    return _socketClient.send(command, apiKey, params);
  }

  Future<void> fetchPlayerSelectionList() async {
    try {
      final result = await _sendCommand('getPlayers');
      _players = (result as List)
          .map((item) => PlayerSelectionItem.fromMap(item))
          .toList();
      _safeNotifyListeners();
    } catch (e) {
      debugPrint('Failed to fetch player list: $e');
      rethrow;
    }
  }

  Future<void> fetchSessionPanelList(
      {int? playerId, bool onlyActive = false}) async {
    _lastSessionPlayerIdFilter = playerId;
    _lastSessionActiveOnlyFilter = onlyActive;
    try {
      final result = await _sendCommand(
          'getSessions', {'playerId': playerId, 'onlyActive': onlyActive});
      _sessions = (result as List)
          .map((item) => SessionPanelItem.fromMap(item))
          .toList();
      _safeNotifyListeners();
    } catch (e) {
      debugPrint('Failed to fetch session list: $e');
      rethrow;
    }
  }

  Future<int> addSession(Session session) async {
    final result = await _sendCommand('addSession', session.toMap());
    await _fetchAllData();
    return result['sessionId'];
  }

  Future<void> updateSession(Session session) async {
    await _sendCommand('updateSession', session.toMap());
    await _fetchAllData();
  }

  Future<void> stopAllSessions(DateTime stopTime) async {
    final stopEpoch = stopTime.millisecondsSinceEpoch ~/ 1000;
    await _sendCommand('stopAllSessions', {'stopEpoch': stopEpoch});
    await backupDatabase();
    await _fetchAllData();
  }

  Future<PlayerSelectionItem> addPayment(
      Map<String, dynamic> paymentMap) async {
    final result = await _sendCommand('addPayment', paymentMap);
    await fetchPlayerSelectionList();
    return PlayerSelectionItem.fromMap(result);
  }

  Future<void> backupDatabase() async {
    await _sendCommand('backupDatabase');
  }

  Future<void> reloadServerDatabase() async {
    await _sendCommand('reloadDatabase');
    await _fetchAllData();
  }

  void _safeNotifyListeners() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mounted) {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _mounted = false;
    _socketClient.disconnect();
    super.dispose();
  }
}