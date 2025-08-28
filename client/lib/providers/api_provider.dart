import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/player_selection_item.dart';
import '../models/session_panel_item.dart';
import '../models/payment.dart';
import '../models/session.dart';

class ApiProvider with ChangeNotifier {
  final String _baseUrl = 'http://localhost:8080'; // URL of your local Dart server

  // The UI can use this status to show a "connecting..." or "server offline" message
  bool _isServerAvailable = true;
  bool get isServerAvailable => _isServerAvailable;

  // Generic helper to handle requests and errors
  Future<T> _handleRequest<T>(Future<http.Response> Function() request, T Function(dynamic) fromJson) async {
    try {
      final response = await request();
      if (response.statusCode == 200) {
        if (!_isServerAvailable) {
          _isServerAvailable = true;
          notifyListeners();
        }
        return fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed request with status: ${response.statusCode}');
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

  // --- API Methods for the UI ---

  Future<List<PlayerSelectionItem>> fetchPlayerSelectionList() async {
    return _handleRequest(
      () => http.get(Uri.parse('$_baseUrl/players')),
      (json) => (json as List).map((item) => PlayerSelectionItem.fromMap(item)).toList()
    );
  }

  Future<List<SessionPanelItem>> fetchSessionPanelList() async {
    return _handleRequest(
      () => http.get(Uri.parse('$_baseUrl/sessions')),
      (json) => (json as List).map((item) => SessionPanelItem.fromMap(item)).toList()
    );
  }

  Future<void> addPayment(Payment payment) async {
    await http.post(
      Uri.parse('$_baseUrl/payments'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payment.toMap()),
    );
    notifyListeners(); // Tell the UI to refresh data
  }

  Future<void> addSession(Session session) async {
    await http.post(
      Uri.parse('$_baseUrl/sessions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(session.toMap()),
    );
    notifyListeners();
  }

  Future<void> updateSession(Session session) async {
    await http.put(
      Uri.parse('$_baseUrl/sessions/${session.sessionId}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(session.toMap()),
    );
    notifyListeners();
  }

  Future<void> triggerBackup() async {
    await http.post(Uri.parse('$_baseUrl/backup'));
    // No need to notify listeners, this is a background task
  }
}
