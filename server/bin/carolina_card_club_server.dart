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
// Import all constants from the shared package
import 'package:shared/shared.dart';

Database? _database;
final Set<WebSocketChannel> _clients = {};

void main() async {
  sqfliteFfiInit();
  await _downloadDatabase();

  final router = Router()
    ..get('/ws', (Request request) {
      // Get the connection info from the request context provided by shelf_io
      final connectionInfo =
          request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
      final ip = connectionInfo?.remoteAddress.address ?? 'unknown IP';

      final handler = webSocketHandler((WebSocketChannel webSocket) {
        // Use the captured IP address in the log message
        print('✓ Client connected via WebSocket from $ip');
        _clients.add(webSocket);

        // Send an immediate acknowledgment message to break client connection timeout.
        final ackMessage =
            jsonEncode({'type': 'ack', 'message': 'Connection acknowledged'});
        webSocket.sink.add(ackMessage);

        webSocket.stream.listen(
          (message) => _handleWebSocketMessage(webSocket, message),
          onDone: () {
            print('✓ Client disconnected from $ip');
            _clients.remove(webSocket);
          },
          onError: (error) {
            print('✗ WebSocket error for client from $ip: $error');
            _clients.remove(webSocket);
          },
        );
      });
      // Important: call the handler with the request to perform the upgrade
      return handler(request);
    });

  final handler =
      const Pipeline().addMiddleware(logRequests()).addHandler(router.call);

  // Bind to 0.0.0.0 to be accessible on the LAN
  final server = await io.serve(handler, '0.0.0.0', 8080);

  print('✓ Secure WebSocket Server listening on port ${server.port}');
  print('---');
  print(
      'On other devices, connect clients to this machine\'s LAN IP address.');
  print(
      'Find this address using "ifconfig" (macOS/Linux) or "ipconfig" (Windows).');
  print('---');
}

void _broadcastUpdate() {
  print('-> Broadcasting update to ${_clients.length} clients...');
  final message = jsonEncode({'type': 'broadcast', 'event': 'update'});
  for (final client in _clients.toList()) {
    try {
      client.sink.add(message);
    } catch (e) {
      print('Error sending to client, removing: $e');
      _clients.remove(client);
    }
  }
}

void _handleWebSocketMessage(WebSocketChannel ws, dynamic message) {
  try {
    final decoded = jsonDecode(message);
    final requestId = decoded['requestId'];
    final apiKey = decoded['apiKey'];
    final command = decoded['command'];
    final params = decoded['params'];

    if (apiKey != localApiKey) {
      print('✗ Auth failed for a message.');
      ws.sink.add(jsonEncode({
        'type': 'response',
        'requestId': requestId,
        'error': 'Invalid or missing API Key on WebSocket message'
      }));
      return;
    }

    // Route the command to the correct function
    switch (command) {
      case 'getPlayers':
        _getPlayers(ws, requestId);
        break;
      case 'getSessions':
        _getSessions(ws, requestId, params);
        break;
      case 'addSession':
        _addSession(ws, requestId, params);
        break;
      case 'updateSession':
        _updateSession(ws, requestId, params);
        break;
      case 'addPayment':
        _addPayment(ws, requestId, params);
        break;
      case 'backupDatabase':
        _backupDatabase(ws, requestId);
        break;
      default:
        ws.sink.add(jsonEncode({
          'type': 'response',
          'requestId': requestId,
          'error': 'Unknown command: $command'
        }));
    }
  } catch (e) {
    print('Error handling message: $e');
  }
}

Future<Database> get _db async {
  if (_database == null || !_database!.isOpen) {
    final dbPath = p.join(Directory.current.path, dbFileName);
    _database = await databaseFactoryFfi.openDatabase(dbPath);
  }
  return _database!;
}

// --- WebSocket Command Handlers ---

void _sendResponse(WebSocketChannel ws, String requestId, dynamic payload) {
  ws.sink.add(jsonEncode(
      {'type': 'response', 'requestId': requestId, 'payload': payload}));
}

void _sendError(WebSocketChannel ws, String requestId, String error) {
  ws.sink.add(
      jsonEncode({'type': 'response', 'requestId': requestId, 'error': error}));
}

Future<void> _getPlayers(WebSocketChannel ws, String requestId) async {
  try {
    final db = await _db;
    final players = await db.query('Player_Selection_List');
    _sendResponse(ws, requestId, players);
  } catch (e) {
    _sendError(ws, requestId, 'Error fetching players: $e');
  }
}

Future<void> _getSessions(
    WebSocketChannel ws, String requestId, dynamic params) async {
  try {
    final db = await _db;
    final int? playerId = params?['playerId'];
    List<Map<String, dynamic>> sessions;
    if (playerId != null) {
      sessions = await db.query('Session_Panel_List',
          where: 'Player_Id = ?',
          whereArgs: [playerId],
          orderBy: 'Start_Epoch DESC');
    } else {
      sessions =
          await db.query('Session_Panel_List', orderBy: 'Start_Epoch DESC');
    }
    _sendResponse(ws, requestId, sessions);
  } catch (e) {
    _sendError(ws, requestId, 'Error fetching sessions: $e');
  }
}

Future<void> _addSession(
    WebSocketChannel ws, String requestId, dynamic params) async {
  try {
    final db = await _db;
    final id = await db.insert('Session', params);
    _broadcastUpdate();
    _sendResponse(ws, requestId, {'sessionId': id});
  } catch (e) {
    _sendError(ws, requestId, 'Error adding session: $e');
  }
}

Future<void> _updateSession(
    WebSocketChannel ws, String requestId, dynamic params) async {
  try {
    final db = await _db;
    await db.update('Session', params,
        where: 'Session_Id = ?', whereArgs: [params['Session_Id']]);
    _broadcastUpdate();
    _sendResponse(ws, requestId, 'Session updated successfully');
  } catch (e) {
    _sendError(ws, requestId, 'Error updating session: $e');
  }
}

Future<void> _addPayment(
    WebSocketChannel ws, String requestId, dynamic params) async {
  try {
    final db = await _db;
    await db.insert('Payment', params);
    final updatedPlayer = await db.query('Player_Selection_List',
        where: 'Player_Id = ?', whereArgs: [params['Player_Id']]);
    _broadcastUpdate();
    _sendResponse(ws, requestId, updatedPlayer.first);
  } catch (e) {
    _sendError(ws, requestId, 'Error adding payment: $e');
  }
}

Future<void> _backupDatabase(WebSocketChannel ws, String requestId) async {
  print('--- Backup requested ---');
  final dbPath = (await _db).path;
  await _database?.close();
  _database = null;

  try {
    var req = http.MultipartRequest("POST", Uri.parse(uploadUrl))
      ..fields['apiKey'] = remoteApiKey
      ..files.add(await http.MultipartFile.fromPath('database', dbPath,
          filename: dbFileName));

    var res = await req.send();

    if (res.statusCode == 200) {
      print('✓ Backup successful!');
      _broadcastUpdate();
      _sendResponse(ws, requestId, 'Backup successful');
    } else {
      print('✗ Backup failed with status: ${res.statusCode}');
      _sendError(ws, requestId, 'Backup failed with status: ${res.statusCode}');
    }
  } catch (e) {
    print('✗ An error occurred during backup: $e');
    _sendError(ws, requestId, 'An error occurred during backup: $e');
  } finally {
    await _db;
    print('✓ Database re-opened after backup.');
  }
}

Future<void> _downloadDatabase() async {
  print('--- Initializing: Downloading database ---');
  final dbFile = File(p.join(Directory.current.path, dbFileName));
  try {
    final response = await http
        .get(Uri.parse(downloadUrl))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      await dbFile.writeAsBytes(response.bodyBytes);
      print('✓ Database download complete.');
    } else {
      print('✗ Error downloading database. Status: ${response.statusCode}');
      if (!await dbFile.exists()) {
        print('✗ No local database backup found. Exiting.');
        exit(1);
      }
      print('✓ Using existing local database file.');
    }
  } catch (e) {
    print('✗ An error occurred during download: $e');
    if (!await dbFile.exists()) {
      print('✗ No local database backup found. Exiting.');
      exit(1);
    }
    print('✓ Using existing local database file.');
  }
}
