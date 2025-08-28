// client/lib/providers/api_provider.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/player_selection_item.dart';
import '../models/session_panel_item.dart';
import '../models/payment.dart';
import '../models/session.dart';
import 'app_settings_provider.dart';

class ApiProvider with ChangeNotifier {
  // This provider now depends on AppSettingsProvider
  final AppSettingsProvider _appSettingsProvider;

  ApiProvider(this._appSettingsProvider);

  String get _baseUrl => _appSettingsProvider.currentSettings.localServerUrl;
  String get _apiKey => _appSettingsProvider.currentSettings.localServerApiKey;

  bool _isServerAvailable = true;
  bool get isServerAvailable => _isServerAvailable;

  // Helper to add the API key to every request
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'X-Api-Key': _apiKey, // Custom header for our key
  };

  Future<T> _handleRequest<T>(Future<http.Response> Function() request, T Function(dynamic) fromJson) async {
    try {
      final response = await request();
      if (response.statusCode == 403) { // Forbidden
        throw Exception('Invalid API Key. Please check settings.');
      }
      if (response.statusCode == 200) {
        if (!_isServerAvailable) {
          _isServerAvailable = true;
          notifyListeners();
        }
        return fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed request: ${response.statusCode}');
      }
    } catch (e) {
      if (_isServerAvailable) {
        _isServerAvailable = false;
        notifyListeners();
      }
      debugPrint('API Error: $e');
      throw Exception('Could not connect to the local server.');
    }
  }

  Future<List<PlayerSelectionItem>> fetchPlayerSelectionList() async {
    return _handleRequest(
      () => http.get(Uri.parse('$_baseUrl/players'), headers: _headers),
      (json) => (json as List).map((item) => PlayerSelectionItem.fromMap(item)).toList()
    );
  }

  Future<List<SessionPanelItem>> fetchSessionPanelList() async {
    return _handleRequest(
      () => http.get(Uri.parse('$_baseUrl/sessions'), headers: _headers),
      (json) => (json as List).map((item) => SessionPanelItem.fromMap(item)).toList()
    );
  }

  Future<PlayerSelectionItem> addPayment(Payment payment) async {
    return _handleRequest(
      () => http.post(Uri.parse('$_baseUrl/payments'), headers: _headers, body: jsonEncode(payment.toMap())),
      (json) => PlayerSelectionItem.fromMap(json)
    );
  }

  Future<int> addSession(Session session) async {
    return _handleRequest(
      () => http.post(Uri.parse('$_baseUrl/sessions'), headers: _headers, body: jsonEncode(session.toMap())),
      (json) => json['sessionId']
    );
  }

  Future<void> updateSession(Session session) async {
    await http.put(Uri.parse('$_baseUrl/sessions/${session.sessionId}'), headers: _headers, body: jsonEncode(session.toMap()));
    notifyListeners();
  }

  Future<void> triggerBackup() async {
    await http.post(Uri.parse('$_baseUrl/backup'), headers: _headers);
    notifyListeners();
  }
}
