import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared/shared.dart';

import '../models/app_settings.dart';
import '../models/player_selection_item.dart';
import '../models/session_panel_item.dart';
import '../models/session.dart';
import 'app_settings_provider.dart';

enum ServerStatus { connecting, connected, disconnected }

class ApiProvider with ChangeNotifier {
  late AppSettingsProvider _appSettingsProvider;
  ServerStatus _serverStatus = ServerStatus.disconnected;
  WebSocketChannel? _channel;
  StreamSubscription? _streamSubscription;
  final Map<String, Completer> _requests = {};
  final Uuid _uuid = const Uuid();
  bool _isConnecting = false;

  ServerStatus get serverStatus => _serverStatus;

  ApiProvider(this._appSettingsProvider);

  Future<void> initialize() async {
    await _connect();
  }

  void updateAppSettings(AppSettingsProvider newSettingsProvider) {
    if (!newSettingsProvider.isInitialized) {
      _appSettingsProvider = newSettingsProvider;
      return;
    }

    final oldUrl = _appSettingsProvider.currentSettings.localServerUrl;
    final newUrl = newSettingsProvider.currentSettings.localServerUrl;

    _appSettingsProvider = newSettingsProvider;

    if (oldUrl != newUrl && !_isConnecting) {
      print('--> Server URL changed by user. Forcing reconnect...');
      // Here, _disconnect is appropriate because a connection likely existed.
      _disconnect().then((_) => _connect());
    }
  }

  Future<void> _connect() async {
    if (_isConnecting) return;
    _isConnecting = true;

    final Completer<void> connectionCompleter = Completer<void>();

    final serverUrl = _appSettingsProvider.currentSettings.localServerUrl;
    if (_serverStatus != ServerStatus.connecting) {
      _serverStatus = ServerStatus.connecting;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          notifyListeners();
        }
      });
    }

    try {
      await _disconnect();

      final wsUrl = Uri.parse(serverUrl.replaceFirst('http', 'ws') + '/ws');
      _channel = IOWebSocketChannel.connect(
        wsUrl,
        connectTimeout: const Duration(seconds: 10),
      );

      _streamSubscription = _channel!.stream.listen(
        (message) {
          if (!connectionCompleter.isCompleted) {
            final decoded = jsonDecode(message as String);
            if (decoded['type'] == 'ack') {
              print('✓ Handshake successful. Connected to $serverUrl.');
              _serverStatus = ServerStatus.connected;
              notifyListeners();
              connectionCompleter.complete();
            } else {
              connectionCompleter
                  .completeError(Exception('Invalid handshake message from server.'));
            }
          } else {
            _handleServerMessage(message);
          }
        },
        onError: (error) {
          if (!connectionCompleter.isCompleted) {
            connectionCompleter.completeError(error);
          }
          _handleConnectionEnd(serverUrl, 'ERROR: $error');
        },
        onDone: () {
          if (!connectionCompleter.isCompleted) {
            connectionCompleter
                .completeError(Exception('Connection closed during handshake.'));
          }
          _handleConnectionEnd(serverUrl, 'Connection closed by server.');
        },
      );

      await connectionCompleter.future;
    } catch (e) {
      print('✗ FAILED to connect to $serverUrl: $e');
      // THE FIX: Call the new hard-reset method instead of _disconnect.
      _resetConnectionState();
      throw e;
    } finally {
      _isConnecting = false;
    }
  }

  /// Performs a graceful disconnection from an active connection.
  Future<void> _disconnect() async {
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    await _channel?.sink.close();
    _channel = null;

    if (_serverStatus != ServerStatus.disconnected) {
      _serverStatus = ServerStatus.disconnected;
      notifyListeners();
    }
  }

  /// Performs a "hard" reset of connection variables without attempting
  /// a graceful network closure. This is safe to call when a connection
  /// failed to establish.
  void _resetConnectionState() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _channel = null;

    if (_serverStatus != ServerStatus.disconnected) {
      _serverStatus = ServerStatus.disconnected;
      notifyListeners();
    }
  }

  void _handleConnectionEnd(String serverUrl, String reason) {
    print('--> [!] WebSocket connection to $serverUrl ended: $reason');
    // _disconnect is appropriate here as a connection existed.
    _disconnect();
  }

  void _handleServerMessage(dynamic message) {
    try {
      if (message != null && (message as String).contains('"type":"ack"')) {
        return;
      }

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
        notifyListeners();
      }
    } catch (e) {
      print('Error handling server message: $e');
    }
  }

  Future<dynamic> _sendCommand(
      String command, [Map<String, dynamic>? params]) async {
    if (_serverStatus != ServerStatus.connected) {
      throw Exception('Not connected to the server.');
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

  // --- Public API Methods ---
  Future<List<PlayerSelectionItem>> fetchPlayerSelectionList() async {
    final result = await _sendCommand('getPlayers');
    return (result as List)
        .map((item) => PlayerSelectionItem.fromMap(item))
        .toList();
  }

  Future<List<SessionPanelItem>> fetchSessionPanelList({int? playerId}) async {
    final result = await _sendCommand('getSessions', {'playerId': playerId});
    return (result as List)
        .map((item) => SessionPanelItem.fromMap(item))
        .toList();
  }

  Future<int> addSession(Session session) async {
    final result = await _sendCommand('addSession', session.toMap());
    return result['sessionId'];
  }

  Future<void> updateSession(Session session) async {
    await _sendCommand('updateSession', session.toMap());
  }

  Future<PlayerSelectionItem> addPayment(
      Map<String, dynamic> paymentMap) async {
    final result = await _sendCommand('addPayment', paymentMap);
    return PlayerSelectionItem.fromMap(result);
  }

  Future<void> backupDatabase() async {
    await _sendCommand('backupDatabase');
  }

  Future<void> reloadServerDatabase() async {
    await _sendCommand('reloadDatabase');
  }

  // A helper to check if the provider is still mounted before notifying listeners.
  bool get mounted => _appSettingsProvider.isInitialized;

  @override
  void dispose() {
    _disconnect();
    super.dispose();
  }
}
