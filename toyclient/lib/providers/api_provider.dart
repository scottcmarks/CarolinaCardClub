// lib/providers/api_provider.dart

import 'dart:convert';
import 'app_settings_provider.dart';
import 'db_connection_provider.dart';

/// A specific implementation of the DbConnectionProvider.
/// It handles API-specific messages and reacts to changes in AppSettingsProvider.
class ApiProvider extends DbConnectionProvider {
  AppSettingsProvider _appSettingsProvider;

  ApiProvider(this._appSettingsProvider) : super(_handleApiMessage);

  static void _handleApiMessage(dynamic message) {
    try {
      final decoded = jsonDecode(message as String);
      print('--> [TOY API] Message received: $decoded');
    } catch (e) {
      print('--> [TOY API] Error decoding message: $e');
    }
  }

  /// This method now contains the connection logic. It's called by the
  /// ChangeNotifierProxyProvider whenever the AppSettingsProvider changes.
  void updateAppSettings(AppSettingsProvider newSettings) {
    _appSettingsProvider = newSettings;

    // THE FIX: If the settings provider is still loading, do nothing.
    // The proxy provider will call this method again once loading is complete.
    if (newSettings.isLoading) {
      return;
    }

    final newUrl = newSettings.currentSettings.serverUrl;

    // Do nothing if the settings change but the URL is the same as the active one.
    if (newUrl == connectedUrl && status == ConnectionStatus.connected) {
      return;
    }

    if (newUrl.isEmpty) {
      // If the desired URL is empty, ensure we are disconnected.
      if (status != ConnectionStatus.disconnected) {
        disconnect();
      }
    } else {
      // If there is a new URL, connect to it.
      connect(newUrl);
    }
  }
}
