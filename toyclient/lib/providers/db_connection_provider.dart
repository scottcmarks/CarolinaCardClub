// lib/providers/db_connection_provider.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum ConnectionStatus { disconnected, connecting, connected, failed }

/// A concrete class to manage a WebSocket connection.
/// It is a ChangeNotifier and can be used directly or composed into other providers.
class DbConnectionProvider with ChangeNotifier {
  final void Function(dynamic message) _handleServerMessage;
  WebSocketChannel? _channel;
  StreamSubscription? _streamSubscription;

  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  String? _lastError;
  String? _connectingUrl;
  String? _connectedUrl; // Tracks the URL of the active connection.
  int _connectionAttempt = 0;
  bool _isClosing = false;

  ConnectionStatus get status => _connectionStatus;
  String? get lastError => _lastError;
  String? get connectingUrl => _connectingUrl;
  String? get connectedUrl => _connectedUrl;

  DbConnectionProvider(this._handleServerMessage);

  /// Centralized logic to react to server URL changes.
  void setServerUrl(String newUrl) {
    // Do nothing if the settings change but the URL is the same as the active one.
    if (newUrl == _connectedUrl && _connectionStatus == ConnectionStatus.connected) {
      return;
    }

    if (newUrl.isEmpty) {
      // If the desired URL is empty, ensure we are disconnected.
      if (_connectionStatus != ConnectionStatus.disconnected) {
        disconnect();
      }
    } else {
      // If there is a new URL, connect to it.
      connect(newUrl);
    }
  }

  Future<void> _cleanupConnection() async {
    if (_isClosing) return;
    _isClosing = true;

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

  Future<void> connect(String url) async {
    final int attemptId = ++_connectionAttempt;
    await disconnect();
    if (attemptId != _connectionAttempt) return;

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
            try {
              final decoded = jsonDecode(message as String);
              if (decoded['type'] == 'ack') {
                handshakeCompleter.complete();
              }
            } catch (e) {
              handshakeCompleter.completeError(Exception('Invalid handshake'));
            }
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
            handshakeCompleter
                .completeError(Exception('Connection closed during handshake'));
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

  Future<void> disconnect() async {
    await _cleanupConnection();
    if (_connectionStatus != ConnectionStatus.disconnected) {
      _connectionStatus = ConnectionStatus.disconnected;
      notifyListeners();
    }
  }
}
