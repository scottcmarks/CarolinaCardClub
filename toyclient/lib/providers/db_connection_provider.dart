// lib/providers/db_connection_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// This enum is now part of the generic connection provider
enum ConnectionStatus { disconnected, connecting, connected, failed }

/// A generic provider for managing a WebSocket connection to a database server.
/// This class handles connection state, timeouts, and race conditions.
/// It must be extended by a specific implementation that provides a message handler.
abstract class DbConnectionProvider with ChangeNotifier {
  WebSocketChannel? _channel;
  StreamSubscription? _streamSubscription;
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  String? _lastError;
  String? _connectingUrl;
  String? _connectedUrl; // New: Tracks the URL of the active connection.
  int _connectionAttempt = 0;
  bool _isClosing = false;

  final void Function(dynamic message) _handleServerMessage;

  // Public getters for the UI
  ConnectionStatus get status => _connectionStatus;
  String? get lastError => _lastError;
  String? get connectingUrl => _connectingUrl;
  String? get connectedUrl => _connectedUrl; // New: Getter for the connected URL.

  /// Constructor requires a message handler from the implementing class.
  DbConnectionProvider(this._handleServerMessage);

  Future<void> _cleanupConnection() async {
    if (_isClosing) return;
    _isClosing = true;
    print('--> [DB] Cleaning up connection...');
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    try {
      await _channel?.sink.close().timeout(const Duration(seconds: 1));
      print('--> [DB] Channel closed.');
    } on TimeoutException {
      print('--> [DB] Channel close timed out. Proceeding anyway.');
    } catch (e) {
      print('--> [DB] Error closing channel: $e');
    }
    _channel = null;
    _isClosing = false;
    _connectedUrl = null; // New: Clear the connected URL on cleanup.
  }

  Future<void> connect(String url) async {
    final int attemptId = ++_connectionAttempt;
    await disconnect();

    if (attemptId != _connectionAttempt) {
      print('--> [DB] Connection attempt #$attemptId was cancelled.');
      return;
    }

    _connectionStatus = ConnectionStatus.connecting;
    _connectingUrl = url;
    _lastError = null;
    notifyListeners();

    print('--> [DB] Attempt #$attemptId: Connecting to $url...');
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
          // Once the handshake is complete, pass all subsequent messages to the handler.
          if (handshakeCompleter.isCompleted) {
            _handleServerMessage(message);
          } else {
            // Logic to complete the handshake
            if (message.contains('ack')) {
              handshakeCompleter.complete();
              print('--> [DB] Handshake complete.');
            }
          }
        },
        onError: (error) {
          if (!handshakeCompleter.isCompleted) {
            handshakeCompleter.completeError(error);
          } else {
            print('--> [DB] Stream error: $error');
          }
        },
        onDone: () {
          print('--> [DB] Stream is done.');
          if (!handshakeCompleter.isCompleted) {
            handshakeCompleter.completeError(Exception('Connection closed'));
          }
          disconnect();
        },
      );

      await handshakeCompleter.future;

      print('--> [DB] Attempt #$attemptId: Connection successful.');
      _connectionStatus = ConnectionStatus.connected;
      _connectedUrl = url; // New: Set the connected URL on success.

    } catch (e) {
      print('--> [DB] Attempt #$attemptId: FAILED to connect: $e');
      _connectionStatus = ConnectionStatus.failed;
      _lastError = e.toString();
      await _cleanupConnection();
    } finally {
      if (attemptId == _connectionAttempt) {
        _connectingUrl = null;
        notifyListeners();
      } else {
         print('--> [DB] Attempt #$attemptId was superseded. Ignoring result.');
      }
    }
  }

  Future<void> disconnect() async {
    print('--> [DB] Disconnecting...');
    await _cleanupConnection();
    if (_connectionStatus != ConnectionStatus.disconnected) {
      _connectionStatus = ConnectionStatus.disconnected;
      notifyListeners();
    }
  }
}
