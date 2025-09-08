// lib/providers/api_provider.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import './app_settings_provider.dart';

enum ConnectionStatus { disconnected, connecting, connected, failed }

class ApiProvider with ChangeNotifier {
  AppSettingsProvider _appSettingsProvider;
  WebSocketChannel? _channel;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  String? _lastError;
  String? _connectingUrl;
  int _connectionAttempt = 0;

  // New variable to prevent re-entrant calls to cleanup.
  bool _isClosing = false;

  ConnectionStatus get status => _status;
  String? get lastError => _lastError;
  String? get connectingUrl => _connectingUrl;

  ApiProvider(this._appSettingsProvider);

  void updateAppSettings(AppSettingsProvider newSettings) {
    _appSettingsProvider = newSettings;
  }

  /// Helper to clean up connection resources without changing state.
  /// Now includes a timeout and a guard flag.
  Future<void> _cleanupConnection() async {
    if (_isClosing) {
      print('--> [TOY] Channel already closing.');
      return;
    }
    _isClosing = true;
    try {
      await _channel?.sink.close().timeout(const Duration(seconds: 1));
      print('--> [TOY] Channel closed.');
    } on TimeoutException {
      // The channel did not close within the specified time, so move on.
      print('--> [TOY] Channel close timed out. Proceeding anyway.');
    } catch (e) {
      // Handle other potential errors during the closing process.
      print('--> [TOY] Error closing channel: $e');
    }
    _channel = null;
    _isClosing = false;
  }

  Future<void> connect(String url) async {
    // Increment the attempt counter and capture the current attempt number.
    final int attemptId = ++_connectionAttempt;

    // Disconnect first to ensure a clean state before proceeding.
    await disconnect();

    // Check if a newer attempt has started while we were disconnecting.
    if (attemptId != _connectionAttempt) {
      print('--> [TOY] Connection attempt #$attemptId was cancelled before starting.');
      return;
    }

    // Now, set the "connecting" state and notify the UI.
    _status = ConnectionStatus.connecting;
    _connectingUrl = url;
    _lastError = null;
    notifyListeners();

    print('--> [TOY] Attempt #$attemptId: Attempting to connect to $url...');
    try {
      final wsUrl = Uri.parse(url.replaceFirst('http', 'ws') + '/ws');
      _channel = IOWebSocketChannel.connect(
        wsUrl,
        connectTimeout: const Duration(seconds: 5),
      );

      await _channel!.ready;

      final completer = Completer<void>();
      final sub = _channel!.stream.listen(
        (message) {
          try {
            final decoded = jsonDecode(message as String);
            if (decoded['type'] == 'ack' && !completer.isCompleted) {
              completer.complete();
            }
          } catch (e) {
            if (!completer.isCompleted) {
              completer.completeError(Exception('Invalid handshake message'));
            }
          }
        },
        onError: (error) {
          if (!completer.isCompleted) completer.completeError(error);
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.completeError(Exception('Connection closed during handshake'));
          }
        },
      );

      await completer.future;
      sub.cancel();

      print('--> [TOY] Attempt #$attemptId: Connection successful to $url.');
      // On success, update the status but do NOT notify yet.
      _status = ConnectionStatus.connected;

    } on TimeoutException catch (e) {
      print('--> [TOY] Attempt #$attemptId: FAILED to connect to $url: timed out. (1)');
      // On failure, update the status and error, but do NOT notify yet.
      _status = ConnectionStatus.failed;
      _lastError = "Timed out";
      await _cleanupConnection();
    } catch (e) {
      print('--> [TOY] Attempt #$attemptId: FAILED to connect to $url: $e');
      // On failure, update the status and error, but do NOT notify yet.
      _status = ConnectionStatus.failed;
      _lastError = e.toString();
      await _cleanupConnection();
    } finally {
      // THE FIX: Only notify the UI if this is still the most current attempt.
      if (attemptId == _connectionAttempt) {
        print('--> [TOY] Attempt #$attemptId: This is the latest attempt. Updating UI.');
        _connectingUrl = null;
        notifyListeners();
      } else {
        print('--> [TOY] Attempt #$attemptId: A newer attempt has started. Discarding result.');
      }
    }
  }

  Future<void> disconnect() async {
    print('--> [TOY] Disconnecting...');
    await _cleanupConnection(); // Use the helper here as well.
    if (_status != ConnectionStatus.disconnected) {
      _status = ConnectionStatus.disconnected;
      notifyListeners();
    }
  }
}
