// server/bin/carolina_card_club_server.dart

import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared/shared.dart';

Database? _database;
final Set<WebSocketChannel> _clients = {};

void main() async {
  sqfliteFfiInit();
  await _downloadDatabase();

  final router = Router()..all('/ws', _webSocketHandler);

  final ipLoggingMiddleware =
      createMiddleware(requestHandler: (Request request) {
    if (request.headers['connection'] == 'Upgrade' &&
        request.headers['upgrade'] == 'websocket') {
      final connectionInfo =
          request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
      final address = connectionInfo?.remoteAddress.address ?? 'unknown';
      print('✓ WebSocket connection attempt from $address');
    }
    return null;
  });

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(ipLoggingMiddleware)
      .addHandler(router);

  final server = await io.serve(handler, '0.0.0.0', 5109);
  print('✓ Secure WebSocket Server listening on port ${server.port}');
  print('---');
}

// --- Helper Methods ---
void _sendResponse(WebSocketChannel ws, String requestId, dynamic payload) {
  ws.sink.add(jsonEncode({
    'type': 'response',
    'requestId': requestId,
    'payload': payload,
  }));
}

void _sendError(WebSocketChannel ws, String requestId, String message) {
  ws.sink.add(jsonEncode({
    'type': 'response',
    'requestId': requestId,
    'error': message,
  }));
}

Future<void> _handleWebSocketMessage(
    WebSocketChannel webSocket, String message) async {
  String? currentRequestId;
  try {
    final decoded = jsonDecode(message);
    currentRequestId = decoded['requestId'];
    final apiKey = decoded['apiKey'];
    final command = decoded['command'];
    final params = decoded['params'];

    if (apiKey != localApiKey) {
      if (currentRequestId != null) {
        _sendError(webSocket, currentRequestId, 'Invalid API Key');
      }
      return;
    }

    dynamic payload;

    switch (command) {
      case 'getPlayers':
        payload = await _getPlayers();
        break;
      case 'getPokerTables':
        payload = await _getPokerTables();
        break;
      case 'updateTableStatus':
        await _updateTableStatus(params!);
        payload = {'status': 'ok'};
        break;
      case 'getPlayerCategories':
        payload = await _getPlayerCategories();
        break;
      case 'getSessions':
        payload = await _getSessions(params);
        break;
      case 'addSession':
        payload = {'sessionId': await _addSession(params!)};
        break;
      case 'updateSession':
        await _updateSession(params!);
        payload = {'status': 'ok'};
        break;
      case 'stopAllSessions':
        await _stopAllSessions(params!);
        payload = {'status': 'ok'};
        break;
      case 'addPayment':
        payload = await _addPayment(params!);
        break;
      case 'backupDatabase':
        await _backupDatabase();
        payload = {'status': 'ok'};
        _broadcastUpdate();
        break;
      case 'reloadDatabase':
        await _reloadDatabase();
        payload = {'status': 'ok'};
        _broadcastUpdate();
        break;
      default:
        _sendError(webSocket, currentRequestId!, 'Unknown command: $command');
        return;
    }

    _sendResponse(webSocket, currentRequestId!, payload);

  } catch (e) {
    print('✗ Error handling message: $e');
    if (currentRequestId != null) {
      _sendError(webSocket, currentRequestId, 'Server error: $e');
    }
  }
}

final _webSocketHandler =
    webSocketHandler((WebSocketChannel webSocket, String? protocol) {
  print('✓ Client connection established.');
  _clients.add(webSocket);
  webSocket.sink.add(jsonEncode({'type': 'ack'}));

  webSocket.stream.listen(
    (message) => _handleWebSocketMessage(webSocket, message),
    onDone: () {
      print('✓ Client disconnected.');
      _clients.remove(webSocket);
    },
    onError: (error) {
      print('✗ WebSocket error: $error');
      _clients.remove(webSocket);
    },
  );
});

void _broadcastUpdate() {
  final message = jsonEncode({'type': 'broadcast', 'event': 'update'});
  for (final client in _clients.toList()) {
    try {
      client.sink.add(message);
    } catch (e) {
      _clients.remove(client);
    }
  }
}

Future<Database> get _db async {
  if (_database == null || !_database!.isOpen) {
    final dbPath = p.join(Directory.current.path, dbFileName);
    _database = await databaseFactoryFfi.openDatabase(dbPath);
  }
  return _database!;
}

// --- Database Logic ---
Future<List<Map<String, Object?>>> _getPlayers() async {
  final db = await _db;
  return await db.query('Player_Selection_List');
}

Future<List<Map<String, Object?>>> _getPokerTables() async {
  final db = await _db;
  // Return ALL tables (active and inactive) so UI can toggle them
  return await db.query('PokerTable', orderBy: 'Name ASC');
}

Future<void> _updateTableStatus(Map<String, dynamic> params) async {
  final db = await _db;
  await db.update(
    'PokerTable',
    {'IsActive': params['isActive'] ? 1 : 0},
    where: 'PokerTable_Id = ?',
    whereArgs: [params['tableId']],
  );
  _broadcastUpdate();
}

Future<List<Map<String, Object?>>> _getPlayerCategories() async {
  final db = await _db;
  return await db.query('Player_Category_Rate_Interval_List');
}

Future<List<Map<String, Object?>>> _getSessions(
    Map<String, dynamic>? params) async {
  final db = await _db;
  final int? playerId = params?['playerId'];
  final bool onlyActive = params?['onlyActive'] ?? false;

  List<String> whereClauses = [];
  List<dynamic> whereArgs = [];

  if (playerId != null) {
    whereClauses.add('Player_Id = ?');
    whereArgs.add(playerId);
  }

  if (onlyActive) {
    whereClauses.add('Stop_Epoch IS NULL');
  }

  String? whereString =
      whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

  return await db.query(
    'Session_Panel_List',
    where: whereString,
    whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
    orderBy: 'Start_Epoch DESC',
  );
}

Future<int> _addSession(Map<String, dynamic> sessionData) async {
  final db = await _db;
  final id = await db.insert('Session', sessionData);
  _broadcastUpdate();
  return id;
}

Future<void> _updateSession(Map<String, dynamic> sessionData) async {
  final db = await _db;
  await db.update('Session', sessionData,
      where: 'Session_Id = ?', whereArgs: [sessionData['Session_Id']]);
  _broadcastUpdate();
}

Future<void> _stopAllSessions(Map<String, dynamic> params) async {
  final db = await _db;
  final int? stopEpoch = params['stopEpoch'];
  if (stopEpoch == null) throw Exception('stopEpoch required');

  await db.update(
    'Session',
    {'Stop_Epoch': stopEpoch},
    where: 'Stop_Epoch IS NULL',
  );
  _broadcastUpdate();
}

Future<Map<String, Object?>> _addPayment(
    Map<String, dynamic> paymentData) async {
  final db = await _db;
  await db.insert('Payment', paymentData);
  final updatedPlayer = await db.query('Player_Selection_List',
      where: 'Player_Id = ?', whereArgs: [paymentData['Player_Id']]);
  _broadcastUpdate();
  return updatedPlayer.first;
}

Future<void> _backupDatabase() async {
  final dbPath = (await _db).path;
  await _database?.close();
  _database = null;

  try {
    var req = http.MultipartRequest("POST", Uri.parse(uploadUrl))
      ..fields['apiKey'] = remoteApiKey
      ..files.add(await http.MultipartFile.fromPath('database', dbPath,
          filename: dbFileName));
    var res = await req.send();
    if (res.statusCode != 200) throw Exception('Backup failed: ${res.statusCode}');
  } finally {
    await _db;
  }
}

Future<void> _downloadDatabase() async {
  final dbFile = File(p.join(Directory.current.path, dbFileName));
  try {
    final response =
        await http.get(Uri.parse('$downloadUrl?apiKey=$remoteApiKey')).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      await dbFile.writeAsBytes(response.bodyBytes);
    }
  } catch (e) {
    if (!await dbFile.exists()) exit(1);
  }
}

Future<void> _reloadDatabase() async {
  print('--- Reload requested ---');
  await _database?.close();
  _database = null;
  await _downloadDatabase();
  await _db;
  print('✓ Database reloaded and re-opened.');
}
