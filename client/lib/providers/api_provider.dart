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
  bool _mounted = true;

  ServerStatus get serverStatus => _serverStatus;

  ApiProvider(this._appSettingsProvider);

  /// This is the method the UI's FutureBuilder will listen to.
  /// It now throws a clear, high-level exception on failure.
  Future<void> initialize() async {
    final bool success = await _connect();
    if (!success) {
      throw Exception('Failed to establish connection with the server.');
    }
  }

  /// This only updates the internal settings reference. It no longer
  /// triggers a reconnect, which prevents race conditions.
  void updateAppSettings(AppSettingsProvider newSettingsProvider) {
    _appSettingsProvider = newSettingsProvider;
  }

  /// Attempts to connect to the server.
  /// Returns `true` on success and `false` on failure.
  /// This method NO LONGER THROWS exceptions, it catches them internally.
  Future<bool> _connect() async {
    if (_isConnecting) return false;
    _isConnecting = true;

    final serverUrl = _appSettingsProvider.currentSettings.localServerUrl;
    _serverStatus = ServerStatus.connecting;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mounted) notifyListeners();
    });

    try {
      await _disconnect();

      final wsUrl = Uri.parse(serverUrl.replaceFirst('http', 'ws') + '/ws');
      _channel = IOWebSocketChannel.connect(
        wsUrl,
        connectTimeout: const Duration(seconds: 10),
      );

      final connectionCompleter = Completer<void>();
      _streamSubscription = _channel!.stream.listen(
        (message) {
          if (!connectionCompleter.isCompleted) {
            final decoded = jsonDecode(message as String);
            if (decoded['type'] == 'ack') {
              connectionCompleter.complete();
            } else {
              connectionCompleter.completeError(
                  Exception('Invalid handshake message from server.'));
            }
          } else {
            _handleServerMessage(message);
          }
        },
        onError: (error) {
          if (!connectionCompleter.isCompleted) {
            connectionCompleter.completeError(error);
          }
        },
        onDone: () {
          if (!connectionCompleter.isCompleted) {
            connectionCompleter.completeError(
                Exception('Connection closed during handshake.'));
          }
        },
      );

      await connectionCompleter.future;

      print('✓ Handshake successful. Connected to $serverUrl.');
      _serverStatus = ServerStatus.connected;
      if (_mounted) notifyListeners();
      _isConnecting = false;
      return true; // Signal success
    } catch (e) {
      print('✗ FAILED to connect to $serverUrl: $e');
      _resetConnectionState();
      _isConnecting = false;
      return false; // Signal failure
    }
  }

  Future<void> _disconnect() async {
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    if (_channel != null) {
      await _channel!.sink.close();
      _channel = null;
    }
    if (_serverStatus != ServerStatus.disconnected) {
      _serverStatus = ServerStatus.disconnected;
      if (_mounted) notifyListeners();
    }
  }

  void _resetConnectionState() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _channel = null;
    if (_serverStatus != ServerStatus.disconnected) {
      _serverStatus = ServerStatus.disconnected;
      if (_mounted) notifyListeners();
    }
  }

  void _handleConnectionEnd(String serverUrl, String reason) {
    print('--> [!] WebSocket connection to $serverUrl ended: $reason');
    _disconnect();
  }

  void _handleServerMessage(dynamic message) {
    try {
      if ((message as String).contains('"type":"ack"')) return;

      final decoded = jsonDecode(message);
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
        if (_mounted) notifyListeners();
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

  @override
  void dispose() {
    _mounted = false;
    _disconnect();
    super.dispose();
  }
}
