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

enum ServerStatus { disconnected, connecting, connected, failed }

class ApiProvider with ChangeNotifier {
  AppSettingsProvider _appSettingsProvider;
  final Map<String, Completer> _requests = {};
  final Uuid _uuid = const Uuid();
  WebSocketChannel? _channel;
  StreamSubscription? _streamSubscription;

  ServerStatus _serverStatus = ServerStatus.disconnected;
  String? _lastError;
  String? _connectingUrl;
  int _connectionAttempt = 0;
  bool _isClosing = false;
  bool _mounted = true;

  late Future<void> connectionFuture;

  ServerStatus get serverStatus => _serverStatus;
  String? get lastError => _lastError;
  String? get connectingUrl => _connectingUrl;

  ApiProvider(this._appSettingsProvider) {
    connectionFuture = Completer<void>().future;
  }

  void initialize() {
    connectionFuture = connect();
    notifyListeners();
  }

  void updateAppSettings(AppSettingsProvider newSettingsProvider) {
    final oldUrl = _appSettingsProvider.currentSettings.localServerUrl;
    _appSettingsProvider = newSettingsProvider;
    final newUrl = _appSettingsProvider.currentSettings.localServerUrl;

    if (oldUrl != newUrl) {
      print('--> Server URL changed. Forcing reconnect...');
      connectionFuture = connect();
      notifyListeners();
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
    final int attemptId = ++_connectionAttempt;

    await disconnect();

    if (attemptId != _connectionAttempt) {
      print('--> Connection attempt #$attemptId was cancelled before starting.');
      return;
    }

    _serverStatus = ServerStatus.connecting;
    _connectingUrl = _appSettingsProvider.currentSettings.localServerUrl;
    _lastError = null;
    _safeNotifyListeners();

    final serverUrl = _connectingUrl!;
    print('--> Attempt #$attemptId: Attempting to connect to $serverUrl...');

    try {
      final wsUrl = Uri.parse(serverUrl.replaceFirst('http', 'ws') + '/ws');
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
                print('--> Attempt #$attemptId: Handshake successful.');
                handshakeCompleter.complete();
              } else {
                handshakeCompleter.completeError(
                    Exception('Invalid handshake message from server.'));
              }
            } catch (e) {
              handshakeCompleter
                  .completeError(Exception('Failed to parse handshake message: $e'));
            }
          } else {
            _handleServerMessage(message);
          }
        },
        onError: (error) {
          if (!handshakeCompleter.isCompleted) {
            handshakeCompleter.completeError(error);
          } else {
            print('--> WebSocket connection error after handshake: $error');
            disconnect();
          }
        },
        onDone: () {
          if (!handshakeCompleter.isCompleted) {
            handshakeCompleter
                .completeError(Exception('Connection closed during handshake.'));
          } else {
            print('--> WebSocket connection closed by server after handshake.');
            disconnect();
          }
        },
      );

      await handshakeCompleter.future;

      if (attemptId == _connectionAttempt) {
        _serverStatus = ServerStatus.connected;
      }
    } on WebSocketChannelException catch (e) {
      print('--> Attempt #$attemptId: FAILED to connect to $serverUrl (WebSocketChannelException): $e');
      if (attemptId == _connectionAttempt) {
        _serverStatus = ServerStatus.failed;
        _lastError = e.message ?? "WebSocket connection failed.";
        await _cleanupConnection();
        throw e;
      }
    } on TimeoutException catch (e) {
      print('--> Attempt #$attemptId: FAILED to connect to $serverUrl (TimeoutException): $e');
      if (attemptId == _connectionAttempt) {
        _serverStatus = ServerStatus.failed;
        _lastError = "Connection timed out.";
        await _cleanupConnection();
        throw e;
      }
    } catch (e) {
      print('--> Attempt #$attemptId: FAILED to connect to $serverUrl (Unknown Error): $e');
      if (attemptId == _connectionAttempt) {
        _serverStatus = ServerStatus.failed;
        _lastError = "An unknown error occurred: ${e.toString()}";
        await _cleanupConnection();
        throw e;
      }
    } finally {
      if (attemptId == _connectionAttempt && _serverStatus == ServerStatus.connected) {
        print('--> Attempt #$attemptId: This is the latest attempt and it succeeded. Updating UI state.');
        _connectingUrl = null;
        _safeNotifyListeners();
      } else if (attemptId != _connectionAttempt) {
         print('--> Attempt #$attemptId: A newer attempt has started. Discarding result.');
      }
    }
  }

  Future<void> _cleanupConnection() async {
    if (_isClosing) return;
    _isClosing = true;
    try {
      await _streamSubscription?.cancel();
      _streamSubscription = null;
      await _channel?.sink.close().timeout(const Duration(seconds: 1));
      print('--> Channel closed.');
    } on TimeoutException {
      print('--> Channel close timed out. Proceeding anyway.');
    } catch (e) {
      print('--> Error closing channel: $e');
    }
    _channel = null;
    _isClosing = false;
  }

  Future<void> disconnect() async {
    print('--> Disconnecting...');
    await _cleanupConnection();
    if (_serverStatus != ServerStatus.disconnected) {
      _serverStatus = ServerStatus.disconnected;
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
        _safeNotifyListeners();
      }
    } catch (e) {
      print('Error handling server message: $e');
    }
  }

  Future<dynamic> _sendCommand(
      String command, [Map<String, dynamic>? params]) async {
    if (serverStatus != ServerStatus.connected) {
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

  // THE FIX: Added a new 'onlyActive' parameter to the method signature.
  Future<List<SessionPanelItem>> fetchSessionPanelList(
      {int? playerId, bool onlyActive = false}) async {
    // THE FIX: Pass the 'onlyActive' flag to the server in the parameters map.
    // print('-->  fetchSessionPanelList: playerId: ${playerId}, onlyActive: ${onlyActive} ...');
    final result = await _sendCommand(
        'getSessions', {'playerId': playerId, 'onlyActive': onlyActive});
    // print('-->  fetchSessionPanelList ... result = ${result}');
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
    disconnect();
    super.dispose();
  }
}
