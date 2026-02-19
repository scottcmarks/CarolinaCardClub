// client/lib/providers/api_provider.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared/shared.dart';
import '../models/player_selection_item.dart';
import '../models/session.dart';
import '../models/poker_table.dart';

class ApiProvider with ChangeNotifier {
  final String _baseUrl = 'http://${Shared.defaultServerIp}:${Shared.defaultServerPort}';
  final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'x-api-key': Shared.defaultLocalApiKey,
  };

  List<PlayerSelectionItem> players = [];
  List<Session> sessions = [];
  List<PokerTable> pokerTables = Shared.tables; // Using tables from Shared
  bool isClubOpen = false;
  int? clubStartEpoch;

  // Initialize
  Future<void> init() async {
    await fetchState();
    await fetchPlayers();
    await fetchSessions();
  }

  Future<void> fetchState() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/state'), headers: _headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        isClubOpen = data['Is_Club_Open'] == 1;
        clubStartEpoch = data['Club_Start_Epoch'];
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching state: $e');
    }
  }

  Future<void> toggleClubSession(bool open) async {
    final newEpoch = open ? (DateTime.now().millisecondsSinceEpoch ~/ 1000) : null;
    final response = await http.post(
      Uri.parse('$_baseUrl/state/toggle'),
      headers: _headers,
      body: json.encode({'Is_Club_Open': open ? 1 : 0, 'Club_Start_Epoch': newEpoch}),
    );

    if (response.statusCode == 200) {
      isClubOpen = open;
      clubStartEpoch = newEpoch;
      notifyListeners();
    } else {
      throw Exception('Server rejected state toggle');
    }
  }

  Future<void> fetchPlayers() async {
    final response = await http.get(Uri.parse('$_baseUrl/players/selection'), headers: _headers);
    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      players = data.map((json) => PlayerSelectionItem.fromJson(json)).toList();
      notifyListeners();
    }
  }

  Future<void> fetchSessions() async {
    final response = await http.get(Uri.parse('$_baseUrl/sessions/panel'), headers: _headers);
    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      sessions = data.map((json) => Session.fromJson(json)).toList();
      notifyListeners();
    }
  }

  Future<void> addSession(Session session) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/sessions'),
      headers: _headers,
      body: json.encode(session.toJson()),
    );
    if (response.statusCode != 200) {
      final err = json.decode(response.body);
      throw Exception(err['error'] ?? 'Failed to add session');
    }
    await fetchSessions();
  }

  Future<void> stopSession(int sessionId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/sessions/stop'),
      headers: _headers,
      body: json.encode({
        'Session_Id': sessionId,
        'Stop_Epoch': (DateTime.now().millisecondsSinceEpoch ~/ 1000),
      }),
    );
    if (response.statusCode == 200) {
      await fetchSessions();
      await fetchPlayers();
    }
  }

  Future<void> addPayment({required int playerId, required double amount}) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/payments'),
      headers: _headers,
      body: json.encode({
        'Player_Id': playerId,
        'Amount': amount,
        'Payment_Date_Epoch': (DateTime.now().millisecondsSinceEpoch ~/ 1000),
        'Payment_Method': 'Cash',
        'Notes': 'Prepaid Session'
      }),
    );
    if (response.statusCode != 200) throw Exception('Payment failed');
    await fetchPlayers();
  }
}