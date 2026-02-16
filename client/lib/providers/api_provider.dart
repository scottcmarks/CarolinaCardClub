// client/lib/providers/api_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';

import '../logic/balance_calculator.dart';
import '../models/player_selection_item.dart';
import '../models/session.dart';
import '../models/session_panel_item.dart';
import '../models/poker_table.dart';
import '../services/socket_client.dart';
import 'app_settings_provider.dart';

export '../services/socket_client.dart' show ConnectionStatus;

class ApiProvider with ChangeNotifier {
  AppSettingsProvider _appSettingsProvider;
  final SocketClient _socketClient = SocketClient();

  // Data State
  List<PlayerSelectionItem> _players = [];
  List<SessionPanelItem> _sessions = [];
  List<PokerTable> _pokerTables = [];
  DateTime? _clubSessionStartDateTime;

  // Game Rules State
  double _defaultHourlyRate = 5.0;
  int _defaultPrepayHours = 5;

  // Filter State
  int? _lastSessionPlayerIdFilter;
  bool _lastSessionActiveOnlyFilter = false;

  bool _mounted = true;
  String? _currentConnectionUrl;
  bool _hasAttemptedAutoScan = false;

  // Getters
  List<PlayerSelectionItem> get players => _players;
  List<SessionPanelItem> get sessions => _sessions;
  List<PokerTable> get pokerTables => _pokerTables;
  DateTime? get clubSessionStartDateTime => _clubSessionStartDateTime;

  double get defaultHourlyRate => _defaultHourlyRate;
  int get defaultPrepayHours => _defaultPrepayHours;

  ConnectionStatus get connectionStatus => _socketClient.status;
  String? get lastError => _socketClient.lastError;
  String? get connectingUrl => _currentConnectionUrl;
  bool get hasAttemptedAutoScan => _hasAttemptedAutoScan;

  Future<void> connectionFuture = Completer<void>().future;

  ApiProvider(this._appSettingsProvider) {
    _currentConnectionUrl = _appSettingsProvider.currentSettings.localServerUrl;

    _socketClient.statusNotifier.addListener(() {
      _safeNotifyListeners();
    });

    _socketClient.onBroadcast.listen((message) {
      if (message['event'] == 'update') {
        _fetchAllData().catchError((e) {
          debugPrint('ApiProvider: Failed to update data from broadcast: $e');
        });
      }
    });
  }

  // --- MISSING METHODS ADDED HERE ---

  void updateAppSettings(AppSettingsProvider appSettingsProvider) {
    _appSettingsProvider = appSettingsProvider;
    final newUrl = _appSettingsProvider.currentSettings.localServerUrl;

    if (_currentConnectionUrl != newUrl) {
      _currentConnectionUrl = newUrl;
      _socketClient.disconnect();
      connect();
    }
  }

  Future<void> retryConnection() async {
    _hasAttemptedAutoScan = false; // Reset to allow loading spinner logic
    _safeNotifyListeners();
    await connect();
  }

  void markAutoScanAttempted() {
    _hasAttemptedAutoScan = true;
    _safeNotifyListeners();
  }

  Future<void> updateServerUrl(String newUrl) async {
    // 1. Update local state
    _currentConnectionUrl = newUrl;

    // 2. Persist to settings
    try {
      await _appSettingsProvider.updateSettings(
        _appSettingsProvider.currentSettings.copyWith(localServerUrl: newUrl)
      );
    } catch (e) {
      debugPrint("Warning: Could not save settings: $e");
    }

    // 3. Reconnect
    await _socketClient.disconnect();
    await connect();
  }

  // ----------------------------------

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

    await _socketClient.connect(_currentConnectionUrl!, apiKey);

    if (connectionStatus == ConnectionStatus.connected) {
      try {
        await _fetchAllData();
      } catch (e) {
        debugPrint('ApiProvider: Error fetching initial data: $e');
        await _socketClient.disconnect();
      }
    }
  }

  Future<void> _fetchAllData() async {
    await Future.wait([
      fetchPlayerSelectionList(),
      fetchSessionPanelList(
        playerId: _lastSessionPlayerIdFilter,
        onlyActive: _lastSessionActiveOnlyFilter,
      ),
      fetchPokerTables(),
      fetchClubSessionStatus(),
    ]);
  }

  Future<List<T>> _fetchList<T>(
      String command,
      Map<String, dynamic>? params,
      T Function(Map<String, dynamic>) fromMap
  ) async {
    final result = await _sendCommand(command, params);
    return (result as List).map((item) => fromMap(item)).toList();
  }

  Future<void> fetchPlayerSelectionList() async {
    _players = await _fetchList('getPlayers', null, PlayerSelectionItem.fromMap);
    _safeNotifyListeners();
  }

  Future<void> fetchSessionPanelList({int? playerId, bool onlyActive = false}) async {
    _lastSessionPlayerIdFilter = playerId;
    _lastSessionActiveOnlyFilter = onlyActive;
    _sessions = await _fetchList(
      'getSessions',
      {'playerId': playerId, 'onlyActive': onlyActive},
      SessionPanelItem.fromMap
    );
    _safeNotifyListeners();
  }

  Future<void> fetchPokerTables() async {
    _pokerTables = await _fetchList('getPokerTables', null, PokerTable.fromMap);
    _safeNotifyListeners();
  }

  Future<void> toggleTableStatus(int tableId, bool isActive) async {
    await _sendCommand('updateTableStatus', {'tableId': tableId, 'isActive': isActive});
    await fetchPokerTables();
  }

  Future<void> fetchClubSessionStatus() async {
    try {
      final result = await _sendCommand('getPlayerCategories');
      final categories = List<Map<String, dynamic>>.from(result);

      final regularCategory = categories.firstWhere(
        (cat) => cat['Name'] == 'Regular',
        orElse: () => {},
      );

      if (regularCategory.isNotEmpty && regularCategory['Stop'] == null) {
         if (regularCategory['Rate_Start_Epoch'] != null) {
           int startEpoch = regularCategory['Rate_Start_Epoch'];
           _clubSessionStartDateTime = DateTime.fromMillisecondsSinceEpoch(startEpoch * 1000);
         }
      } else {
        _clubSessionStartDateTime = null;
      }
      if (regularCategory.isNotEmpty) {
        if (regularCategory['Rate'] != null) {
          _defaultHourlyRate = (regularCategory['Rate'] as num).toDouble();
        }
        if (regularCategory['Prepay_Hours'] != null) {
          _defaultPrepayHours = (regularCategory['Prepay_Hours'] as int);
        }
      }
      _safeNotifyListeners();
    } catch (e) {
      debugPrint('Error fetching session status: $e');
    }
  }

  double getDynamicBalance({
    required int playerId,
    required DateTime currentTime,
  }) {
    return BalanceCalculator.getDynamicBalance(
      playerId: playerId,
      currentTime: currentTime,
      clubSessionStartDateTime: _clubSessionStartDateTime,
      players: _players,
      sessions: _sessions,
    );
  }

  Future<dynamic> _sendCommand(String command, [Map<String, dynamic>? params]) async {
    final apiKey = _appSettingsProvider.currentSettings.localServerApiKey;
    return _socketClient.send(command, apiKey, params);
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

  Future<PlayerSelectionItem> addPayment(Map<String, dynamic> paymentMap) async {
    final result = await _sendCommand('addPayment', paymentMap);
    await fetchPlayerSelectionList();
    return PlayerSelectionItem.fromMap(result);
  }

  Future<void> backupDatabase() async { await _sendCommand('backupDatabase'); }
  Future<void> reloadServerDatabase() async {
    await _sendCommand('reloadDatabase');
    await _fetchAllData();
  }

  void _safeNotifyListeners() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mounted) notifyListeners();
    });
  }

  @override
  void dispose() {
    _mounted = false;
    _socketClient.disconnect();
    super.dispose();
  }
}