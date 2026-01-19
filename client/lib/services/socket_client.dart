// client/lib/services/socket_client.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// **fix**: Added 'initial' to prevent the error screen flash on startup
enum ConnectionStatus { initial, disconnected, connecting, connected, failed }

class SocketClient {
  WebSocketChannel? _channel;
  StreamSubscription? _streamSubscription;

  final Map<String, Completer> _requests = {};
  final Uuid _uuid = const Uuid();

  // Initialize as 'initial' so the UI knows we haven't even tried yet
  final ValueNotifier<ConnectionStatus> statusNotifier =
      ValueNotifier(ConnectionStatus.initial);

  final StreamController<Map<String, dynamic>> _broadcastController =
      StreamController.broadcast();

  String? _lastError;
  bool _isClosing = false;
  int _connectionAttempt = -1;

  ConnectionStatus get status => statusNotifier.value;
  String? get lastError => _lastError;
  Stream<Map<String, dynamic>> get onBroadcast => _broadcastController.stream;

  Future<void> connect(String serverUrl, String apiKey) async {
    final int attemptId = ++_connectionAttempt;

    await disconnect();

    if (attemptId != _connectionAttempt) return;

    statusNotifier.value = ConnectionStatus.connecting;
    _lastError = null;

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
            _handleHandshake(message, handshakeCompleter);
          } else {
            _handleMessage(message);
          }
        },
        onError: (error) {
          if (!handshakeCompleter.isCompleted) {
            handshakeCompleter.completeError(error);
          } else {
            _failConnection(error.toString());
          }
        },
        onDone: () {
          if (!handshakeCompleter.isCompleted) {
            handshakeCompleter.completeError(
                Exception('Connection closed during handshake.'));
          } else {
            disconnect();
          }
        },
      );

      await handshakeCompleter.future;

      if (attemptId == _connectionAttempt) {
        statusNotifier.value = ConnectionStatus.connected;
      }
    } catch (e) {
      if (attemptId == _connectionAttempt) {
        _lastError = "Connection error: ${e.toString()}";
        statusNotifier.value = ConnectionStatus.failed;
        await _cleanup();
      }
    }
  }

  void _handleHandshake(dynamic message, Completer<void> completer) {
    try {
      final decoded = jsonDecode(message as String);
      if (decoded['type'] == 'ack') {
        completer.complete();
      } else {
        completer.completeError(
            Exception('Invalid handshake message from server.'));
      }
    } catch (e) {
      completer.completeError(
          Exception('Failed to parse handshake message: $e'));
    }
  }

  void _handleMessage(dynamic message) {
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

  void _failConnection(String error) {
    _lastError = error;
    statusNotifier.value = ConnectionStatus.failed;
    disconnect();
  }

  Future<dynamic> send(String command, String apiKey,
      [Map<String, dynamic>? params]) async {

    if (status != ConnectionStatus.connected) {
      throw Exception('Not connected to the server.');
    }

    final requestId = _uuid.v4();
    final completer = Completer<dynamic>();
    _requests[requestId] = completer;

    try {
      _channel!.sink.add(jsonEncode({
        'requestId': requestId,
        'apiKey': apiKey,
        'command': command,
        'params': params,
      }));
    } catch (e) {
      _requests.remove(requestId);
      rethrow;
    }

    return completer.future.timeout(const Duration(seconds: 15), onTimeout: () {
      _requests.remove(requestId);
      throw TimeoutException(
          'Server did not respond in time for command: $command');
    });
  }

  Future<void> disconnect() async {
    await _cleanup();
    if (statusNotifier.value != ConnectionStatus.disconnected) {
      statusNotifier.value = ConnectionStatus.disconnected;
    }
  }

  Future<void> _cleanup() async {
    if (_isClosing) return;
    _isClosing = true;
    try {
      await _streamSubscription?.cancel();
      _streamSubscription = null;
      await _channel?.sink.close().timeout(const Duration(seconds: 1));
    } catch (e) {
      // Ignore cleanup errors
    }
    _channel = null;

    for (var completer in _requests.values) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('Connection closed'));
      }
    }
    _requests.clear();

    _isClosing = false;
  }
}