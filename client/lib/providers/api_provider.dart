// client/lib/providers/api_provider.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/player_selection_item.dart';
import '../models/session.dart';
import '../models/session_panel_item.dart';
import 'app_settings_provider.dart';

enum ConnectionStatus { disconnected, connecting, connected, failed }

class ApiProvider with ChangeNotifier {
  AppSettingsProvider _appSettingsProvider;
  final Map<String, Completer> _requests = {};
  final Uuid _uuid = const Uuid();
  WebSocketChannel? _channel;
  StreamSubscription? _streamSubscription;

  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  String? _lastError;
  String? _currentConnectionUrl;
  int _connectionAttempt = -1;
  bool _isClosing = true;
  bool _mounted = true;

  late Future<void> connectionFuture;

  List<PlayerSelectionItem> _players = [];
  List<SessionPanelItem> _sessions = [];
  int? _lastSessionPlayerIdFilter;
  bool _lastSessionActiveOnlyFilter = false;

  List<PlayerSelectionItem> get players => _players;
  List<SessionPanelItem> get sessions => _sessions;
  ConnectionStatus get connectionStatus => _connectionStatus;
  String? get lastError => _lastError;
  String? get connectingUrl => _currentConnectionUrl;

  ApiProvider(this._appSettingsProvider) {
    _currentConnectionUrl = _appSettingsProvider.currentSettings.localServerUrl;
    connectionFuture = Completer<void>().future;
  }

  void initialize() {
    if (_connectionStatus == ConnectionStatus.connecting || _connectionStatus == ConnectionStatus.connected) {
      return;
    }
    _connectionStatus = ConnectionStatus.connecting;
    _lastError = null;
    notifyListeners();

    connectionFuture = connect();
    connectionFuture.then((_) async {
      if (connectionStatus == ConnectionStatus.connected) {
        await fetchPlayerSelectionList();
        await fetchSessionPanelList();
      }
    });
  }

  void retryConnection() {
    initialize();
  }

  void updateAppSettings(AppSettingsProvider newSettingsProvider) {
    final newUrl = newSettingsProvider.currentSettings.localServerUrl;
    if (_currentConnectionUrl != newUrl) {
      debugPrint(
          '--> Server URL changed from "$_currentConnectionUrl" to "$newUrl". Forcing reconnect...');
      _appSettingsProvider = newSettingsProvider;
      _currentConnectionUrl = newUrl;
      retryConnection();
    } else {
      _appSettingsProvider = newSettingsProvider;
    }
  }

  void _safeNotifyListeners() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mounted) {
        notifyListeners();
      }
    });
  }

  Future<void> connect() async {
    // **THE FIX**: Start a timer to measure how long connection takes.
    final stopwatch = Stopwatch()..start();

    final int attemptId = ++_connectionAttempt;
    await disconnect();
    if (attemptId != _connectionAttempt) {
      return;
    }

    _currentConnectionUrl =
        _appSettingsProvider.currentSettings.localServerUrl;
    final serverUrl = _currentConnectionUrl!;

    try {
      final wsUrl = Uri.parse('${serverUrl.replaceFirst('http', 'ws')}/ws');
      _channel = IOWebSocketChannel.connect(
        wsUrl,
        connectTimeout: const Duration(seconds: 10),
      );
      final handshakeCompleter = Completer<void>();
      _streamSubscription = _channel!.stream.listen(
        (message) {
          if (!handshakeCompleter.isCompleted) {
            try {
              final decoded = jsonDecode(message as String);
              if (decoded['type'] == 'ack') {
                handshakeCompleter.complete();
              } else {
                handshakeCompleter.completeError(
                    Exception('Invalid handshake message from server.'));
              }
            } catch (e) {
              handshakeCompleter.completeError(
                  Exception('Failed to parse handshake message: $e'));
            }
          } else {
            _handleServerMessage(message);
          }
        },
        onError: (error) {
          if (!handshakeCompleter.isCompleted) {
            handshakeCompleter.completeError(error);
          } else {
            disconnect();
          }
        },
        onDone: () {
          if (!handshakeCompleter.isCompleted) {
            handshakeCompleter
                .completeError(Exception('Connection closed during handshake.'));
          } else {
            disconnect();
          }
        },
      );
      await handshakeCompleter.future;
      if (attemptId == _connectionAttempt) {
        _connectionStatus = ConnectionStatus.connected;
      }
    } catch (e) {
      if (attemptId == _connectionAttempt) {
        _connectionStatus = ConnectionStatus.failed;
        _lastError = "Connection error: ${e.toString()}";
        await _cleanupConnection();
      }
    } finally {
      // **THE FIX**: Enforce a minimum display time for the spinner.
      final elapsed = stopwatch.elapsedMilliseconds;
      const minDisplayTime = 500; // milliseconds
      if (elapsed < minDisplayTime) {
        await Future.delayed(Duration(milliseconds: minDisplayTime - elapsed));
      }

      _safeNotifyListeners();
    }
  }

  Future<void> _cleanupConnection() async {
    if (_isClosing) return;
    _isClosing = true;
    try {
      await _streamSubscription?.cancel();
      _streamSubscription = null;
      await _channel?.sink.close().timeout(const Duration(seconds: 1));
    } catch (e) {
      // Ignore
    }
    _channel = null;
    _isClosing = false;
  }

  Future<void> disconnect() async {
    await _cleanupConnection();
    if (_connectionStatus != ConnectionStatus.disconnected) {
      _connectionStatus = ConnectionStatus.disconnected;
      _safeNotifyListeners();
    }
  }

  void _handleServerMessage(dynamic message) {
    try {
      final decoded = jsonDecode(message as String);
      final type = decoded['type'];

      if (type == 'response') {
        final requestId = decoded['requestId'];
        if (_requests.containsKey(requestId)) {
          final completer = _requests.remove(requestId)!;
          if (decoded.containsKey('error')) {
            completer.completeError(Exception(decoded['error']));
          } else {
            completer.complete(decoded['payload']);
          }
        }
      } else if (type == 'broadcast' && decoded['event'] == 'update') {
        fetchPlayerSelectionList();
        fetchSessionPanelList(
          playerId: _lastSessionPlayerIdFilter,
          onlyActive: _lastSessionActiveOnlyFilter,
        );
      }
    } catch (e) {
      debugPrint('Error handling server message: $e');
    }
  }

  Future<dynamic> _sendCommand(
      String command, [Map<String, dynamic>? params]) async {
    if (connectionStatus != ConnectionStatus.connected) {
      await connectionFuture;
      if (connectionStatus != ConnectionStatus.connected) {
        throw Exception('Not connected to the server.');
      }
    }
    final requestId = _uuid.v4();
    final completer = Completer<dynamic>();
    _requests[requestId] = completer;
    final apiKey = _appSettingsProvider.currentSettings.localServerApiKey;

    _channel!.sink.add(jsonEncode({
      'requestId': requestId,
      'apiKey': apiKey,
      'command': command,
      'params': params,
    }));

    return completer.future.timeout(const Duration(seconds: 15),
        onTimeout: () {
      _requests.remove(requestId);
      throw TimeoutException(
          'Server did not respond in time for command: $command');
    });
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

  @override
  void dispose() {
    _mounted = false;
    disconnect();
    super.dispose();
  }
}