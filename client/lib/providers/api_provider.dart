// client/lib/providers/api_provider.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
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
  ServerStatus _serverStatus = ServerStatus.connecting;
  WebSocketChannel? _channel;
  StreamSubscription? _streamSubscription;
  final Map<String, Completer> _requests = {};
  final Uuid _uuid = const Uuid();
  bool _isConnecting = false;

  ServerStatus get serverStatus => _serverStatus;

  ApiProvider(this._appSettingsProvider) {
    _connect();
  }

  void updateAppSettings(AppSettingsProvider newSettings) {
    _appSettingsProvider = newSettings;
    _reconnect();
  }

  Future<void> _connect() async {
    if (_isConnecting) {
      return;
    }

    final serverUrl = _appSettingsProvider.currentSettings.localServerUrl;
    print('--> Connecting to WebSocket server at $serverUrl...');
    _serverStatus = ServerStatus.connecting;
    notifyListeners();

    _isConnecting = true;

    try {
      final wsUrl = Uri.parse(serverUrl.replaceFirst('http', 'ws') + '/ws');

      await _streamSubscription?.cancel();
      await _channel?.sink.close();

      final connectionCompleter = Completer<void>();

      _channel = WebSocketChannel.connect(wsUrl);

      _streamSubscription = _channel!.stream.listen(
        (message) {
          if (!connectionCompleter.isCompleted) {
            final decoded = jsonDecode(message);
            if (decoded['type'] == 'ack') {
              connectionCompleter.complete();
            }
          }
          _handleServerMessage(message);
        },
        onDone: () {
          print('--> WebSocket connection to $serverUrl closed.');
          _disconnect();
          _reconnect();
        },
        onError: (error) {
          print('--> WebSocket connection to $serverUrl error: $error');
          if (!connectionCompleter.isCompleted) {
            connectionCompleter.completeError(error);
          }
          _disconnect();
          _reconnect();
        },
      );

      await connectionCompleter.future.timeout(const Duration(seconds: 10));

      print('✓ Connected to $serverUrl.');
      _serverStatus = ServerStatus.connected;
      notifyListeners();
    } catch (e) {
      print('✗ Failed to connect to $serverUrl: $e');
      await _disconnect();
      _reconnect();
    } finally {
      _isConnecting = false;
    }
  }

  void _reconnect() {
    if (_serverStatus == ServerStatus.connected || _isConnecting) return;
    Future.delayed(const Duration(seconds: 5), () {
      if (_serverStatus != ServerStatus.connected) {
        _connect();
      }
    });
  }

  Future<void> _disconnect() async {
    await _streamSubscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _streamSubscription = null;
    if (_serverStatus != ServerStatus.disconnected) {
      _serverStatus = ServerStatus.disconnected;
      notifyListeners();
    }
  }

  void _handleServerMessage(String message) {
    try {
      final decoded = jsonDecode(message);
      final type = decoded['type'];

      if (type == 'response') {
        final requestId = decoded['requestId'];
        if (_requests.containsKey(requestId)) {
          final completer = _requests.remove(requestId)!;
          if (decoded.containsKey('error')) {
            completer.completeError(decoded['error']);
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

  Future<dynamic> _sendCommand(String command,
      [Map<String, dynamic>? params]) async {
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

    return completer.future;
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

  Future<PlayerSelectionItem> addPayment(Map<String, dynamic> paymentMap) async {
    final result = await _sendCommand('addPayment', paymentMap);
    return PlayerSelectionItem.fromMap(result);
  }

  Future<void> backupDatabase() async {
    await _sendCommand('backupDatabase');
  }

  @override
  void dispose() {
    _disconnect();
    super.dispose();
  }
}
