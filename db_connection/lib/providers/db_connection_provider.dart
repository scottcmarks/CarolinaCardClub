// shared/lib/providers/db_connection_provider.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:cupertino_http/cupertino_http.dart';
import 'package:web_socket_channel/adapter_web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum ConnectionStatus { disconnected, connecting, connected, failed }

const _reconnectDelay = Duration(seconds: 5);

/// Manages the WebSocket connection. Automatically reconnects after drops or
/// failures as long as a target URL is set. Call [setServerUrl] to point at
/// a server; call [disconnect] (or pass an empty URL) to stop reconnecting.
class DbConnectionProvider with ChangeNotifier {
  // --- Private State ---
  WebSocketChannel? _channel;
  StreamSubscription? _streamSubscription;
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  String? _lastError;
  String? _connectingUrl;
  String? _connectedUrl;
  String? _targetUrl;          // URL we want to stay connected to
  Timer? _reconnectTimer;
  int _connectionAttempt = 0;
  bool _isClosing = false;

  final Map<String, Completer> _requests = {};
  final Uuid _uuid = const Uuid();

  final _broadcastController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get broadcastStream => _broadcastController.stream;

  // --- Public Getters ---
  ConnectionStatus get status => _connectionStatus;
  String? get lastError => _lastError;
  String? get connectingUrl => _connectingUrl;
  String? get connectedUrl => _connectedUrl;
  bool get isRetryPending => _reconnectTimer?.isActive == true;

  /// Point the provider at a server URL. Triggers an immediate connect attempt
  /// and will keep reconnecting if the connection drops.
  void setServerUrl(String newUrl) {
    if (newUrl.isEmpty) {
      _targetUrl = null;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      disconnect();
      return;
    }
    if (newUrl == _targetUrl &&
        (_connectionStatus == ConnectionStatus.connected ||
         _connectionStatus == ConnectionStatus.connecting)) {
      return;
    }
    _targetUrl = newUrl;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    connect(newUrl);
  }

  /// Establishes a connection to the WebSocket server.
  Future<void> connect(String url) async {
    final int attemptId = ++_connectionAttempt;
    await _cleanupConnection();
    if (attemptId != _connectionAttempt) return;

    _connectionStatus = ConnectionStatus.connecting;
    _connectingUrl = url;
    _lastError = null;
    notifyListeners();

    try {
      final wsUrl = Uri.parse(url.replaceFirst('http', 'ws') + '/ws');

      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.macOS ||
           defaultTargetPlatform == TargetPlatform.iOS)) {
        debugPrint('WS: using CupertinoWebSocket for $wsUrl');
        final ws = await CupertinoWebSocket.connect(wsUrl)
            .timeout(const Duration(seconds: 5));
        _channel = AdapterWebSocketChannel(ws);
      } else {
        _channel = IOWebSocketChannel.connect(
          wsUrl,
          connectTimeout: const Duration(seconds: 5),
        );
      }

      await _channel!.ready;

      final handshakeCompleter = Completer<void>();
      _streamSubscription = _channel!.stream.listen(
        (message) {
          if (!handshakeCompleter.isCompleted) {
            _handleHandshake(message, handshakeCompleter);
          } else {
            _handleServerMessage(message);
          }
        },
        onError: (error) {
          if (!handshakeCompleter.isCompleted) {
            handshakeCompleter.completeError(error);
          } else {
            _connectionDropped();
          }
        },
        onDone: () {
          if (!handshakeCompleter.isCompleted) {
            handshakeCompleter.completeError(Exception('Connection closed during handshake'));
          } else {
            _connectionDropped();
          }
        },
      );

      await handshakeCompleter.future;

      _connectionStatus = ConnectionStatus.connected;
      _connectedUrl = url;
      _broadcastController.add({'event': 'connected'});
    } catch (e) {
      _connectionStatus = ConnectionStatus.failed;
      _lastError = e.toString();
      await _cleanupConnection();
      _scheduleReconnect();
    } finally {
      if (attemptId == _connectionAttempt) {
        _connectingUrl = null;
        notifyListeners();
      }
    }
  }

  /// Intentional disconnect — clears the target URL and stops reconnecting.
  Future<void> disconnect() async {
    _targetUrl = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _cleanupConnection();
    if (_connectionStatus != ConnectionStatus.disconnected) {
      _connectionStatus = ConnectionStatus.disconnected;
      notifyListeners();
    }
  }

  /// Sends a JSON-RPC style command and returns a Future with the response.
  Future<dynamic> sendCommand(String apiKey, String command, [Map<String, dynamic>? params]) {
    if (status != ConnectionStatus.connected) {
      return Future.error(Exception('Not connected to the server.'));
    }

    final requestId = _uuid.v4();
    final completer = Completer<dynamic>();
    _requests[requestId] = completer;

    _channel!.sink.add(jsonEncode({
      'requestId': requestId,
      'apiKey': apiKey,
      'command': command,
      'params': params,
    }));

    return completer.future.timeout(const Duration(seconds: 15), onTimeout: () {
      _requests.remove(requestId);
      throw TimeoutException('Server did not respond in time for command: $command');
    });
  }

  // --- Internal Helper Methods ---

  /// Called when a live connection drops unexpectedly (onDone/onError after handshake).
  void _connectionDropped() {
    _cleanupConnection().then((_) {
      _connectionStatus = ConnectionStatus.failed;
      notifyListeners();
      _scheduleReconnect();
    });
  }

  void _scheduleReconnect() {
    if (_targetUrl == null) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      if (_targetUrl != null) connect(_targetUrl!);
    });
    notifyListeners(); // let UI know retry is now pending
  }

  void _handleHandshake(dynamic message, Completer<void> completer) {
    try {
      final decoded = jsonDecode(message as String);
      if (decoded['type'] == 'ack') {
        completer.complete();
      } else {
        completer.completeError(Exception('Invalid handshake message'));
      }
    } catch (e) {
      completer.completeError(Exception('Invalid handshake JSON: $e'));
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
      } else if (type == 'broadcast') {
        _broadcastController.add(decoded);
      }
    } catch (e) {
      debugPrint('Error handling server message: $e');
    }
  }

  Future<void> _cleanupConnection() async {
    if (_isClosing) return;
    _isClosing = true;

    for (var completer in _requests.values) {
      completer.completeError(Exception('Connection is closing.'));
    }
    _requests.clear();

    await _streamSubscription?.cancel();
    _streamSubscription = null;
    try {
      await _channel?.sink.close().timeout(const Duration(seconds: 1));
    } catch (_) {}
    _channel = null;
    _connectedUrl = null;
    _isClosing = false;
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _broadcastController.close();
    _cleanupConnection();
    super.dispose();
  }
}
