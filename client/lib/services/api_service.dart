// client/lib/services/api_service.dart
//
// Pure HTTP transport — no Flutter state, no ChangeNotifier.
// Every method throws on a non-200 response so callers decide how to handle errors.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared/shared.dart';
import '../models/app_settings.dart';
import '../models/player_selection_item.dart';
import '../models/session.dart';
import '../models/poker_table.dart';

class ApiService {
  final AppSettings settings;

  ApiService(this.settings);

  String get _baseUrl => 'http://${settings.serverIp}:${settings.serverPort}';
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-api-key': settings.localApiKey,
      };

  // ── Fetches ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getState() async {
    final res = await http.get(Uri.parse('$_baseUrl/state'), headers: _headers);
    if (res.statusCode != Shared.httpOK) throw Exception('Failed to get state');
    return jsonDecode(res.body);
  }

  Future<List<PlayerSelectionItem>> getPlayers(int nowEpoch) async {
    final res = await http.get(
        Uri.parse('$_baseUrl/players/selection?epoch=$nowEpoch'),
        headers: _headers);
    if (res.statusCode != Shared.httpOK) throw Exception('Failed to get players');
    final List data = jsonDecode(res.body);
    final items = data.map((json) {
      try {
        return PlayerSelectionItem.fromJson(json);
      } catch (e) {
        debugPrint('⚠️ Player parse error: $e');
        return PlayerSelectionItem(
            playerId: -1, name: 'Parse Error', balance: 0, hourlyRate: 0.0, prepayHours: 0, isActive: false);
      }
    }).toList();
    items.removeWhere((p) => p.playerId == -1);
    return items;
  }

  Future<List<PokerTable>> getTables() async {
    final res = await http.get(Uri.parse('$_baseUrl/tables'), headers: _headers);
    if (res.statusCode != Shared.httpOK) throw Exception('Failed to get tables');
    final List data = jsonDecode(res.body);
    return data.map((json) => PokerTable.fromJson(json)).toList();
  }

  Future<List<Session>> getSessions() async {
    final res = await http.get(Uri.parse('$_baseUrl/sessions/panel'), headers: _headers);
    if (res.statusCode != Shared.httpOK) throw Exception('Failed to get sessions');
    final List data = jsonDecode(res.body);
    return data.map((json) => Session.fromJson(json)).toList();
  }

  // ── Mutations ─────────────────────────────────────────────────────────────

  Future<void> addSession(Session session) async {
    final res = await http.post(Uri.parse('$_baseUrl/sessions'),
        headers: _headers, body: jsonEncode(session.toJson()));
    if (res.statusCode != Shared.httpOK) {
      throw Exception(jsonDecode(res.body)['error'] ?? 'Failed to add session');
    }
  }

  Future<void> stopSession(int sessionId, int stopEpoch) async {
    final res = await http.post(Uri.parse('$_baseUrl/sessions/stop'),
        headers: _headers,
        body: jsonEncode({'Session_Id': sessionId, 'Stop_Epoch': stopEpoch}));
    if (res.statusCode != Shared.httpOK) {
      throw Exception(jsonDecode(res.body)['error'] ?? 'Failed to stop session');
    }
  }

  Future<void> markAway(int sessionId, int awayEpoch) async {
    final res = await http.post(Uri.parse('$_baseUrl/sessions/away'),
        headers: _headers,
        body: jsonEncode({'Session_Id': sessionId, 'Away_Since_Epoch': awayEpoch}));
    if (res.statusCode != Shared.httpOK) {
      throw Exception(jsonDecode(res.body)['error'] ?? 'Failed to mark away');
    }
  }

  Future<void> markReturn(int sessionId) async {
    final res = await http.post(Uri.parse('$_baseUrl/sessions/return'),
        headers: _headers, body: jsonEncode({'Session_Id': sessionId}));
    if (res.statusCode != Shared.httpOK) {
      throw Exception(jsonDecode(res.body)['error'] ?? 'Failed to mark return');
    }
  }

  Future<void> moveSession(int sessionId, int newTableId, int newSeat) async {
    final res = await http.post(Uri.parse('$_baseUrl/sessions/move'),
        headers: _headers,
        body: jsonEncode({
          'Session_Id': sessionId,
          'PokerTable_Id': newTableId,
          'Seat_Number': newSeat,
        }));
    if (res.statusCode != Shared.httpOK) {
      throw Exception(jsonDecode(res.body)['error'] ?? 'Failed to move session');
    }
  }

  Future<void> addPayment(int playerId, int amount, int epoch) async {
    final res = await http.post(Uri.parse('$_baseUrl/payments'),
        headers: _headers,
        body: jsonEncode({'Player_Id': playerId, 'Amount': amount, 'Epoch': epoch}));
    if (res.statusCode != Shared.httpOK) {
      throw Exception(jsonDecode(res.body)['error'] ?? 'Failed to process payment');
    }
  }

  Future<void> toggleClubState(bool isOpen, int? startEpoch) async {
    final res = await http.post(Uri.parse('$_baseUrl/state/toggle'),
        headers: _headers,
        body: jsonEncode({'Is_Club_Open': isOpen, 'Club_Start_Epoch': startEpoch}));
    if (res.statusCode != Shared.httpOK) throw Exception('Failed to toggle club state');
  }

  Future<void> toggleTableStatus(int tableId, bool isActive) async {
    final res = await http.post(Uri.parse('$_baseUrl/tables/toggle'),
        headers: _headers,
        body: jsonEncode({'PokerTable_Id': tableId, 'IsActive': isActive}));
    if (res.statusCode != Shared.httpOK) throw Exception('Failed to toggle table status');
  }

  Future<void> updateDefaultSessionTime(int hour, int minute) async {
    final res = await http.post(Uri.parse('$_baseUrl/state/defaults'),
        headers: _headers, body: jsonEncode({'hour': hour, 'minute': minute}));
    if (res.statusCode != Shared.httpOK) throw Exception('Failed to update default session time');
  }

  Future<void> setClockOffset(int offsetSeconds) async {
    final res = await http.post(Uri.parse('$_baseUrl/state/clock-offset'),
        headers: _headers, body: jsonEncode({'offsetSeconds': offsetSeconds}));
    if (res.statusCode != Shared.httpOK) throw Exception('Failed to set clock offset');
  }

  Future<void> triggerRemoteBackup() async {
    final res = await http.post(Uri.parse('$_baseUrl/maintenance/backup'),
        headers: _headers, body: jsonEncode({'apiKey': settings.localApiKey}));
    if (res.statusCode != Shared.httpOK) {
      throw Exception('Server rejected backup. Check API Key. Status: ${res.statusCode}');
    }
  }

  Future<void> reloadDatabase() async {
    final res = await http.post(Uri.parse('$_baseUrl/system/reload'), headers: _headers);
    if (res.statusCode != Shared.httpOK) throw Exception('Failed to reload server database');
  }
}
