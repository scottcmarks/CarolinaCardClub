// shared/lib/providers/db_connection_provider.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart'; // OPTIMIZED: Depends on foundation, not material.
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum ConnectionStatus { disconnected, connecting, connected, failed }

/// A provider that manages the raw WebSocket connection and the command/response protocol.
/// Its sole responsibility is to maintain the connection and handle the message-passing
/// mechanism, without knowing the specific content of the commands.
class DbConnectionProvider with ChangeNotifier {
  // --- Private State ---
  WebSocketChannel? _channel;
  StreamSubscription? _streamSubscription;
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  String? _lastError;
  String? _connectingUrl;
  String? _connectedUrl;
  int _connectionAttempt = 0;
  bool _isClosing = false;

  final Map<String, Completer> _requests = {};
  final Uuid _uuid = const Uuid();

  // A stream controller to broadcast non-response events (like 'update' broadcasts)
  // to the ApiProvider or other listeners.
  final _broadcastController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get broadcastStream => _broadcastController.stream;

  // --- Public Getters ---
  ConnectionStatus get status => _connectionStatus;
  String? get lastError => _lastError;
  String? get connectingUrl => _connectingUrl;
  String? get connectedUrl => _connectedUrl;

  /// Centralized logic to react to server URL changes from settings.
  void setServerUrl(String newUrl) {
    if (newUrl == _connectedUrl && _connectionStatus == ConnectionStatus.connected) { // CORRECTED
      return;
    }
    if (newUrl.isEmpty) {
      if (_connectionStatus != ConnectionStatus.disconnected) {
        disconnect();
      }
    } else {
      connect(newUrl);
    }
  }

  /// Establishes a connection to the WebSocket server.
  Future<void> connect(String url) async {
    final int attemptId = ++_connectionAttempt;
    await disconnect(); // Ensure any old connection is closed first
    if (attemptId != _connectionAttempt) return; // A new attempt has been started

    _connectionStatus = ConnectionStatus.connecting;
    _connectingUrl = url;
    _lastError = null;
    notifyListeners();

    try {
      final wsUrl = Uri.parse(url.replaceFirst('http', 'ws') + '/ws');
      _channel = IOWebSocketChannel.connect(
        wsUrl,
        connectTimeout: const Duration(seconds: 5),
      );

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
          }
          disconnect();
        },
        onDone: () {
          if (!handshakeCompleter.isCompleted) {
            handshakeCompleter.completeError(Exception('Connection closed during handshake'));
          }
          disconnect();
        },
      );

      await handshakeCompleter.future;

      _connectionStatus = ConnectionStatus.connected;
      _connectedUrl = url;
    } catch (e) {
      _connectionStatus = ConnectionStatus.failed;
      _lastError = e.toString();
      await _cleanupConnection();
    } finally {
      if (attemptId == _connectionAttempt) {
        _connectingUrl = null;
        notifyListeners();
      }
    }
  }

  /// Closes the active WebSocket connection.
  Future<void> disconnect() async {
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
        // Pass broadcast events to the ApiProvider via the stream.
        _broadcastController.add(decoded);
      }
    } catch (e) {
      print('Error handling server message: $e');
    }
  }

  Future<void> _cleanupConnection() async {
    if (_isClosing) return;
    _isClosing = true;

    // Reject all pending requests
    for (var completer in _requests.values) {
        completer.completeError(Exception("Connection is closing."));
    }
    _requests.clear();

    await _streamSubscription?.cancel();
    _streamSubscription = null;
    try {
      await _channel?.sink.close().timeout(const Duration(seconds: 1));
    } catch (_) {
      // Ignore errors on close.
    }
    _channel = null;
    _connectedUrl = null;
    _isClosing = false;
  }

  @override
  void dispose() {
    _broadcastController.close();
    disconnect();
    super.dispose();
  }
}
