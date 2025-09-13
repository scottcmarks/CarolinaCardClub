// lib/providers/api_provider.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'app_settings_provider.dart';
import 'package:db_connection/db_connection.dart';

/// This provider now uses composition ("has-a") instead of inheritance.
/// It manages an instance of DbConnectionProvider and delegates calls to it.
class ApiProvider with ChangeNotifier {
  final DbConnectionProvider _connectionProvider;

  // Public getters to expose the connection status to the UI.
  // These delegate the call to the internal connection provider.
  ConnectionStatus get status => _connectionProvider.status;
  String? get lastError => _connectionProvider.lastError;
  String? get connectingUrl => _connectionProvider.connectingUrl;
  String? get connectedUrl => _connectionProvider.connectedUrl;

  ApiProvider(AppSettingsProvider appSettingsProvider)
      : _connectionProvider = DbConnectionProvider() {
    // Listen for changes on the connection provider and notify our own listeners.
    // This ensures the UI, which listens to ApiProvider, will update.
    _connectionProvider.addListener(notifyListeners);

    // Initial sync
    updateAppSettings(appSettingsProvider);
  }

  /// This method is called by the ChangeNotifierProxyProvider.
  /// Its only job is to pass the new URL to the connection provider.
  void updateAppSettings(AppSettingsProvider newSettings) {
    if (newSettings.isLoading) {
      return;
    }
    final newUrl = newSettings.currentSettings.serverUrl;
    _connectionProvider.setServerUrl(newUrl);
  }

  // When this provider is disposed, we also need to dispose the one it owns.
  @override
  void dispose() {
    _connectionProvider.dispose();
    super.dispose();
  }
}
