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

  final router = Router()
    ..all('/ws', _webSocketHandler);

  // *** NEW: Middleware to log WebSocket connection IPs ***
  final ipLoggingMiddleware = createMiddleware(requestHandler: (Request request) {
    if (request.headers['connection'] == 'Upgrade' && request.headers['upgrade'] == 'websocket') {
      final connectionInfo = request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
      final address = connectionInfo?.remoteAddress.address ?? 'unknown';
      print('✓ WebSocket connection attempt from $address');
    }
    return null; // Continue to the next handler
  });


  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(ipLoggingMiddleware) // Add our new middleware
      .addHandler(router);

  final server = await io.serve(handler, '0.0.0.0', 8080);
  final serverAddress = server.address.host;

  print('✓ Secure WebSocket Server listening on port ${server.port}');
  print('---');
  print('On other devices, connect clients to http://$serverAddress:${server.port}');
  print('Find this address using "ifconfig" (macOS/Linux) or "ipconfig" (Windows).');
  print('---');
}

Future<void> _handleWebSocketMessage(WebSocketChannel webSocket, String message) async {
  try {
    final decoded = jsonDecode(message);
    final requestId = decoded['requestId'];
    final apiKey = decoded['apiKey'];
    final command = decoded['command'];
    final params = decoded['params'];

    if (apiKey != localApiKey) {
      webSocket.sink.add(jsonEncode({
        'type': 'response',
        'requestId': requestId,
        'error': 'Invalid or missing API Key on WebSocket message',
      }));
      return;
    }

    dynamic payload;
    String? error;

    switch (command) {
      case 'getPlayers':
        payload = await _getPlayers();
        break;
      case 'getSessions':
        payload = await _getSessions(params?['playerId']);
        break;
      case 'addSession':
        payload = {'sessionId': await _addSession(params!)};
        break;
      case 'updateSession':
        await _updateSession(params!);
        payload = {'status': 'ok'};
        break;
      case 'addPayment':
        payload = await _addPayment(params!);
        break;
      case 'backupDatabase':
        await _backupDatabase();
        payload = {'status': 'ok'};
        break;
      case 'reloadDatabase':
        await _reloadDatabase();
        payload = {'status': 'ok'};
        _broadcastUpdate();
        break;
      default:
        error = 'Unknown command: $command';
    }

    webSocket.sink.add(jsonEncode({
      'type': 'response',
      'requestId': requestId,
      if (error != null) 'error': error else 'payload': payload,
    }));

  } catch (e) {
    print('✗ Error handling message: $e');
    try {
      final decoded = jsonDecode(message);
      webSocket.sink.add(jsonEncode({
        'type': 'response',
        'requestId': decoded['requestId'],
        'error': 'Server error processing request: $e',
      }));
    } catch (_) {}
  }
}


final _webSocketHandler = webSocketHandler((WebSocketChannel webSocket, {String? protocol}) {
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
  print('-> Broadcasting update to ${_clients.length} clients...');
  final message = jsonEncode({'type': 'broadcast', 'event': 'update'});
  for (final client in _clients.toList()) {
    try {
      client.sink.add(message);
    } catch (e) {
      print('✗ Error sending to client, removing: $e');
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

Future<List<Map<String, Object?>>> _getSessions(int? playerId) async {
  final db = await _db;
  if (playerId != null) {
     return await db.query('Session_Panel_List', where: 'Player_Id = ?', whereArgs: [playerId], orderBy: 'Start_Epoch DESC');
  }
  return await db.query('Session_Panel_List', orderBy: 'Start_Epoch DESC');
}

Future<int> _addSession(Map<String, dynamic> sessionData) async {
  final db = await _db;
  final id = await db.insert('Session', sessionData);
  _broadcastUpdate();
  return id;
}

Future<void> _updateSession(Map<String, dynamic> sessionData) async {
  final db = await _db;
  await db.update('Session', sessionData, where: 'Session_Id = ?', whereArgs: [sessionData['Session_Id']]);
  _broadcastUpdate();
}

Future<Map<String, Object?>> _addPayment(Map<String, dynamic> paymentData) async {
  final db = await _db;
  await db.insert('Payment', paymentData);
  final updatedPlayer = await db.query('Player_Selection_List', where: 'Player_Id = ?', whereArgs: [paymentData['Player_Id']]);
  _broadcastUpdate();
  return updatedPlayer.first;
}

Future<void> _backupDatabase() async {
  print('--- Backup requested ---');
  final dbPath = (await _db).path;
  await _database?.close();
  _database = null;

  try {
    var req = http.MultipartRequest("POST", Uri.parse(uploadUrl))
      ..fields['apiKey'] = remoteApiKey
      ..files.add(await http.MultipartFile.fromPath('database', dbPath, filename: dbFileName));
    var res = await req.send();
    if (res.statusCode == 200) {
      print('✓ Backup successful!');
    } else {
      print('✗ Backup failed with status: ${res.statusCode}');
      throw Exception('Backup failed with status: ${res.statusCode}');
    }
  } catch (e) {
    print('✗ An error occurred during backup: $e');
    rethrow;
  } finally {
    await _db;
    print('✓ Database re-opened after backup.');
  }
}

Future<void> _downloadDatabase() async {
  final dbFile = File(p.join(Directory.current.path, dbFileName));
  try {
    print('--- Downloading database from $downloadUrl ---');
    final response =
        await http.get(Uri.parse(downloadUrl)).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      await dbFile.writeAsBytes(response.bodyBytes);
      print('✓ Database download complete.');
    } else {
      print('✗ Error downloading database. Status: ${response.statusCode}');
      if (!await dbFile.exists()) {
        exit(1);
      }
    }
  } catch (e) {
    print('✗ An error occurred during download: $e');
    if (!await dbFile.exists()) {
      exit(1);
    }
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
