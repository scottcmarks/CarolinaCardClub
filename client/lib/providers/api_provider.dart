// client/lib/providers/api_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';

import '../logic/balance_calculator.dart'; // **NEW IMPORT**
import '../models/player_selection_item.dart';
import '../models/session.dart';
import '../models/session_panel_item.dart';
import '../services/socket_client.dart'; // **NEW IMPORT**
import 'app_settings_provider.dart';

// Export the enum so other files don't break
export '../services/socket_client.dart' show ConnectionStatus;

class ApiProvider with ChangeNotifier {
  AppSettingsProvider _appSettingsProvider;

  // Delegate networking to the service
  final SocketClient _socketClient = SocketClient();

  List<PlayerSelectionItem> _players = [];
  List<SessionPanelItem> _sessions = [];
  int? _lastSessionPlayerIdFilter;
  bool _lastSessionActiveOnlyFilter = false;

  bool _mounted = true;
  String? _currentConnectionUrl;

  List<PlayerSelectionItem> get players => _players;
  List<SessionPanelItem> get sessions => _sessions;
  ConnectionStatus get connectionStatus => _socketClient.status;
  String? get lastError => _socketClient.lastError;
  String? get connectingUrl => _currentConnectionUrl;

  Future<void> connectionFuture = Completer<void>().future;

  ApiProvider(this._appSettingsProvider) {
    _currentConnectionUrl = _appSettingsProvider.currentSettings.localServerUrl;

    // Listen to status changes from the socket client
    _socketClient.statusNotifier.addListener(() {
      _safeNotifyListeners();
    });

    // Listen to broadcast events
    _socketClient.onBroadcast.listen((message) {
      if (message['event'] == 'update') {
        fetchPlayerSelectionList();
        fetchSessionPanelList(
          playerId: _lastSessionPlayerIdFilter,
          onlyActive: _lastSessionActiveOnlyFilter,
        );
      }
    });
  }

  void initialize() {
    if (connectionStatus == ConnectionStatus.connecting ||
        connectionStatus == ConnectionStatus.connected) {
      return;
    }

    connectionFuture = connect();

    connectionFuture.then((_) async {
      if (connectionStatus == ConnectionStatus.connected) {
        await fetchPlayerSelectionList();
        await fetchSessionPanelList();
      }
    });
  }

  Future<void> connect() async {
    _currentConnectionUrl = _appSettingsProvider.currentSettings.localServerUrl;
    final apiKey = _appSettingsProvider.currentSettings.localServerApiKey;

    await _socketClient.connect(_currentConnectionUrl!, apiKey);
  }

  Future<void> disconnect() async {
    await _socketClient.disconnect();
  }

  void retryConnection() {
    initialize();
  }

  void updateAppSettings(AppSettingsProvider newSettingsProvider) {
    final newUrl = newSettingsProvider.currentSettings.localServerUrl;
    if (_currentConnectionUrl != newUrl) {
      debugPrint('--> Server URL changed. Reconnecting...');
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
    await fetchPlayerSelectionList();
    await fetchSessionPanelList(
        playerId: _lastSessionPlayerIdFilter,
        onlyActive: _lastSessionActiveOnlyFilter);
    return result['sessionId'];
  }

  Future<void> updateSession(Session session) async {
    await _sendCommand('updateSession', session.toMap());
    await fetchPlayerSelectionList();
    await fetchSessionPanelList(
        playerId: _lastSessionPlayerIdFilter,
        onlyActive: _lastSessionActiveOnlyFilter);
  }

  Future<void> stopAllSessions(DateTime stopTime) async {
    final stopEpoch = stopTime.millisecondsSinceEpoch ~/ 1000;
    await _sendCommand('stopAllSessions', {'stopEpoch': stopEpoch});
    await backupDatabase();
    await fetchPlayerSelectionList();
    await fetchSessionPanelList(
        playerId: _lastSessionPlayerIdFilter,
        onlyActive: _lastSessionActiveOnlyFilter);
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
    await fetchPlayerSelectionList();
    await fetchSessionPanelList(
        playerId: _lastSessionPlayerIdFilter,
        onlyActive: _lastSessionActiveOnlyFilter);
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