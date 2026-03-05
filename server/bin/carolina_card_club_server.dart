// server/bin/carolina_card_club_server.dart

import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:http/http.dart' as http;
import 'package:shared/shared.dart';

Database? _database;

// Registry of all connected WebSocket clients
final Set<WebSocketChannel> _connectedClients = {};

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final router = Router();

  router.get('/players/selection', _getPlayersHandler);
  router.get('/sessions/panel', _getSessionsHandler);
  router.get('/state', _getStateHandler);
  router.get('/tables', _getTablesHandler);

  router.post('/sessions', _addSessionHandler);
  router.post('/sessions/stop', _stopSessionHandler);
  router.post('/sessions/move', _moveSessionHandler);
  router.post('/payments', _addPaymentHandler);
  router.post('/state/toggle', _toggleStateHandler);
  router.post('/state/clock-offset', _clockOffsetHandler);
  router.post('/tables/toggle', _toggleTableHandler);
  router.post('/state/defaults', _updateDefaultsHandler);

  router.post('/maintenance/backup', _manualBackupHandler);
  router.post('/maintenance/restore', _manualRestoreHandler);
  router.post('/system/reload', _manualReloadHandler);

  // WebSocket handler — not subject to auth middleware, handles its own auth via handshake
  router.get('/ws', webSocketHandler((WebSocketChannel channel, String? protocol) => _webSocketHandler(channel)));

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_corsMiddleware)
      .addMiddleware(_authMiddleware)
      .addHandler(router.call);

  try {
    final port = Shared.defaultServerPort;
    await io.serve(handler, InternetAddress.anyIPv4, port);
    print('====================================================');
    print('✓ Carolina Card Club Server running on port $port');
  } catch (e) {
    print('🛑 Failed to start server: $e');
  }
}

// --- WebSocket Handler ---

void _webSocketHandler(WebSocketChannel channel) async {
  try {
    final db = await _db;

    // Fetch current clock offset to include in the handshake ack
    final stateRows = await db.query('System_State', where: 'Id = 1');
    final int clockOffsetSeconds = stateRows.isNotEmpty
        ? (stateRows.first['Clock_Offset_Seconds'] as int? ?? 0)
        : 0;

    // Send handshake ack with current clock offset
    channel.sink.add(jsonEncode({
      'type': 'ack',
      'clockOffsetSeconds': clockOffsetSeconds,
    }));

    // Register client
    _connectedClients.add(channel);
    print('✓ WebSocket client connected. Total clients: ${_connectedClients.length}');

    // Listen for disconnect
    channel.stream.listen(
      (_) {}, // Clients don't send anything — pager model is server-to-client only
      onDone: () {
        _connectedClients.remove(channel);
        print('WebSocket client disconnected. Total clients: ${_connectedClients.length}');
      },
      onError: (_) {
        _connectedClients.remove(channel);
      },
    );
  } catch (e) {
    print('🛑 ERROR [_webSocketHandler]: $e');
    await channel.sink.close();
  }
}

// --- Broadcast Helper ---

void _broadcastAll(Map<String, dynamic> message) {
  if (_connectedClients.isEmpty) return;
  final encoded = jsonEncode(message);
  final deadClients = <WebSocketChannel>[];

  for (final client in _connectedClients) {
    try {
      client.sink.add(encoded);
    } catch (_) {
      deadClients.add(client);
    }
  }

  for (final dead in deadClients) {
    _connectedClients.remove(dead);
  }
}

void _broadcastStateChanged() {
  _broadcastAll({
    'type': 'broadcast',
    'event': 'state_changed',
  });
}

// --- REST Handlers ---

Future<Response> _addSessionHandler(Request request) async {
  try {
    final data = json.decode(await request.readAsString());
    final db = await _db;

    final int playerId = data['playerId'] ?? data['Player_Id'];

    final active = await db.query('Session',
      where: 'Player_Id = ? AND Stop_Epoch IS NULL',
      whereArgs: [playerId]
    );
    if (active.isNotEmpty) {
      return Response(Shared.httpForbidden, body: json.encode({'error': 'Player already has an active session'}));
    }

    final Map<String, dynamic> insertData = {
      'Player_Id': playerId,
      'Start_Epoch': data['startEpoch'] ?? data['Start_Epoch'],
      'PokerTable_Id': data['pokerTableId'] ?? data['PokerTable_Id'],
      'Seat_Number': data['seatNumber'] ?? data['Seat_Number'],
      'Is_Prepaid': (data['isPrepaid'] == true || data['Is_Prepaid'] == 1) ? 1 : 0,
      'Prepay_Amount': data['prepayAmount'] ?? data['Prepay_Amount'] ?? 0,
      'Hourly_Rate': data['hourlyRate'] ?? data['Hourly_Rate'] ?? 0.0,
    };

    await db.insert('Session', insertData);
    _broadcastStateChanged();
    return Response.ok(json.encode({'success': true}));
  } catch (e) {
    print('🛑 ERROR [_addSessionHandler]: $e');
    return Response.internalServerError(body: '$e');
  }
}

Future<Response> _stopSessionHandler(Request request) async {
  try {
    final data = json.decode(await request.readAsString());
    final db = await _db;

    final sessionId = data['Session_Id'] ?? data['sessionId'];
    final stopEpoch = data['Stop_Epoch'] ?? data['stopEpoch'];

    final active = await db.query('Session', where: 'Session_Id = ?', whereArgs: [sessionId]);
    if (active.isEmpty) {
      return Response(Shared.httpNotFound, body: json.encode({'error': 'Session not found'}));
    }

    await db.update('Session', {'Stop_Epoch': stopEpoch}, where: 'Session_Id = ?', whereArgs: [sessionId]);
    _broadcastStateChanged();
    return Response.ok(json.encode({'success': true}));
  } catch (e) {
    print('🛑 ERROR [_stopSessionHandler]: $e');
    return Response.internalServerError(body: '$e');
  }
}

Future<Response> _moveSessionHandler(Request request) async {
  try {
    final data = json.decode(await request.readAsString());
    final db = await _db;

    final sessionId = data['Session_Id'] ?? data['sessionId'];
    final tableId = data['PokerTable_Id'] ?? data['pokerTableId'];
    final seatNumber = data['Seat_Number'] ?? data['seatNumber'];

    await db.update('Session',
      {'PokerTable_Id': tableId, 'Seat_Number': seatNumber},
      where: 'Session_Id = ?',
      whereArgs: [sessionId]
    );
    _broadcastStateChanged();
    return Response.ok(json.encode({'success': true}));
  } catch (e) {
    return Response.internalServerError(body: '$e');
  }
}

Future<Response> _addPaymentHandler(Request request) async {
  try {
    final data = json.decode(await request.readAsString());
    final db = await _db;

    if (data['Epoch'] == null) {
      return Response(Shared.httpBadRequest, body: json.encode({'error': 'Missing required parameter: Epoch (must use synchronized game time)'}));
    }

    final Map<String, dynamic> insertData = {
      'Player_Id': data['Player_Id'] ?? data['playerId'],
      'Amount': data['Amount'] ?? data['amount'],
      'Epoch': data['Epoch'],
    };

    await db.insert('Payment', insertData);
    _broadcastStateChanged();
    return Response.ok(json.encode({'success': true}));
  } catch (e) {
    print('🛑 ERROR [_addPaymentHandler]: $e');
    return Response.internalServerError(body: '$e');
  }
}

Future<Response> _getPlayersHandler(Request request) async {
  try {
    final db = await _db;

    final epochStr = request.url.queryParameters['epoch'];
    final nowEpoch = epochStr != null ? int.parse(epochStr) : (DateTime.now().millisecondsSinceEpoch ~/ 1000);

    await db.update('System_State', {'Current_Game_Epoch': nowEpoch}, where: 'Id = 1');

    final results = await db.query('Player_Selection_List');

    return Response.ok(json.encode(results), headers: {'Content-Type': 'application/json'});
  } catch (e) {
    print('🛑 ERROR [_getPlayersHandler]: $e');
    return Response.internalServerError(body: '$e');
  }
}

Future<Response> _getSessionsHandler(Request request) async {
  try {
    final db = await _db;
    final results = await db.query('Session_Panel_List');
    return Response.ok(json.encode(results), headers: {'Content-Type': 'application/json'});
  } catch (e) {
    print('🛑 ERROR [_getSessionsHandler]: $e');
    return Response.internalServerError(body: '$e');
  }
}

Future<Response> _getStateHandler(Request request) async {
  try {
    final db = await _db;
    final results = await db.query('System_State', where: 'Id = 1');
    if (results.isEmpty) return Response.internalServerError(body: 'State not initialized');
    return Response.ok(json.encode(results.first), headers: {'Content-Type': 'application/json'});
  } catch (e) {
    print('🛑 ERROR [_getStateHandler]: $e');
    return Response.internalServerError(body: '$e');
  }
}

Future<Response> _getTablesHandler(Request request) async {
  try {
    final db = await _db;
    final results = await db.query('PokerTable');
    return Response.ok(json.encode(results), headers: {'Content-Type': 'application/json'});
  } catch (e) {
    print('🛑 ERROR [_getTablesHandler]: $e');
    return Response.internalServerError(body: '$e');
  }
}

Future<Response> _toggleStateHandler(Request request) async {
  try {
    final data = json.decode(await request.readAsString());
    final db = await _db;

    await db.update('System_State', {
      'Is_Club_Open': (data['Is_Club_Open'] == true || data['Is_Club_Open'] == 1) ? 1 : 0,
      'Club_Start_Epoch': data['Club_Start_Epoch']
    }, where: 'Id = 1');

    _broadcastStateChanged();
    return Response.ok(json.encode({'success': true}));
  } catch (e) {
    print('🛑 ERROR [_toggleStateHandler]: $e');
    return Response.internalServerError(body: '$e');
  }
}

Future<Response> _clockOffsetHandler(Request request) async {
  try {
    final data = json.decode(await request.readAsString());
    final db = await _db;

    final int offsetSeconds = data['offsetSeconds'] ?? 0;

    await db.update('System_State', {
      'Clock_Offset_Seconds': offsetSeconds,
    }, where: 'Id = 1');

    // Broadcast the new offset to all connected clients
    _broadcastAll({
      'type': 'broadcast',
      'event': 'clock_offset',
      'offsetSeconds': offsetSeconds,
    });

    return Response.ok(json.encode({'success': true}));
  } catch (e) {
    print('🛑 ERROR [_clockOffsetHandler]: $e');
    return Response.internalServerError(body: '$e');
  }
}

Future<Response> _toggleTableHandler(Request request) async {
  try {
    final data = json.decode(await request.readAsString());
    final db = await _db;

    final tableId = data['PokerTable_Id'];
    final isActive = (data['IsActive'] == true || data['IsActive'] == 1) ? 1 : 0;

    await db.update('PokerTable', {'IsActive': isActive}, where: 'PokerTable_Id = ?', whereArgs: [tableId]);
    _broadcastStateChanged();
    return Response.ok(json.encode({'success': true}));
  } catch (e) {
    print('🛑 ERROR [_toggleTableHandler]: $e');
    return Response.internalServerError(body: '$e');
  }
}

Future<Response> _updateDefaultsHandler(Request request) async {
  try {
    final data = json.decode(await request.readAsString());
    final db = await _db;

    await db.update('System_State', {
      'Default_Session_Hour': data['hour'],
      'Default_Session_Minute': data['minute']
    }, where: 'Id = 1');

    return Response.ok(json.encode({'success': true}));
  } catch (e) {
    return Response.internalServerError(body: '$e');
  }
}

Future<Response> _manualBackupHandler(Request request) async {
  try {
    print('Initiating remote backup...');
    final dbPath = p.join(Directory.current.path, Shared.dbFileName);
    final file = File(dbPath);

    if (!await file.exists()) {
      return Response(Shared.httpNotFound, body: json.encode({'error': 'Local database file not found.'}));
    }

    final uri = Uri.parse('${Shared.remoteServerBaseUrl}/${Shared.remoteDbHandlerPath}');

    var req = http.MultipartRequest('POST', uri);
    req.fields['apiKey'] = Shared.remoteApiKey;
    req.files.add(await http.MultipartFile.fromPath('database', dbPath));

    var streamedResponse = await req.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == Shared.httpOK) {
      print('✓ Backup successful');
      return Response.ok(json.encode({'success': true, 'message': response.body}));
    } else {
      print('🛑 Backup rejected by remote server: ${response.body}');
      return Response(Shared.httpError, body: json.encode({'error': 'Remote server rejected backup: ${response.body}'}));
    }
  } catch (e) {
    print('🛑 ERROR [_manualBackupHandler]: $e');
    return Response.internalServerError(body: json.encode({'error': e.toString()}));
  }
}

Future<Response> _manualRestoreHandler(Request request) async {
  try {
    print('Initiating remote restore...');
    final uri = Uri.parse('${Shared.remoteServerBaseUrl}/${Shared.remoteDbHandlerPath}?apiKey=${Shared.remoteApiKey}');

    final response = await http.get(uri);

    if (response.statusCode == Shared.httpOK) {
      if (_database != null) {
        await _database!.close();
        _database = null;
      }

      final dbPath = p.join(Directory.current.path, Shared.dbFileName);
      final file = File(dbPath);
      await file.writeAsBytes(response.bodyBytes);

      await _db;

      print('✓ Restore successful. Database reloaded.');
      return Response.ok(json.encode({'success': true}));
    } else {
      print('🛑 Restore failed: ${response.body}');
      return Response(Shared.httpError, body: json.encode({'error': 'Remote server failed to provide backup: ${response.body}'}));
    }
  } catch (e) {
    print('🛑 ERROR [_manualRestoreHandler]: $e');
    return Response.internalServerError(body: json.encode({'error': e.toString()}));
  }
}

Future<Response> _manualReloadHandler(Request request) async {
  try {
    print('Reloading local database connection...');
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    await _db;
    print('✓ Database connection reloaded.');
    return Response.ok(json.encode({'success': true}));
  } catch (e) {
    print('🛑 ERROR [_manualReloadHandler]: $e');
    return Response.internalServerError(body: json.encode({'error': e.toString()}));
  }
}

// --- Middleware ---

Middleware _authMiddleware = (innerHandler) {
  return (request) {
    // Skip auth for WebSocket upgrade requests and OPTIONS preflight
    if (request.method == 'OPTIONS') return innerHandler(request);
    if (request.headers['upgrade'] == 'websocket') return innerHandler(request);
    if (request.headers['x-api-key'] != Shared.defaultLocalApiKey) {
      return Response(Shared.httpForbidden, body: 'Invalid or missing x-api-key');
    }
    return innerHandler(request);
  };
};

Middleware get _corsMiddleware => createMiddleware(
  requestHandler: (req) => req.method == 'OPTIONS' ? Response.ok('', headers: _corsHeaders) : null,
  responseHandler: (res) => res.change(headers: _corsHeaders),
);

const _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type, x-api-key',
};

// --- Database ---

Future<Database> get _db async {
  if (_database != null) return _database!;
  _database = await openDatabase(p.join(Directory.current.path, Shared.dbFileName));

  await _database!.execute('''
    CREATE TABLE IF NOT EXISTS System_State (
        Id INTEGER PRIMARY KEY CHECK (Id = 1),
        Is_Club_Open INTEGER NOT NULL DEFAULT 0,
        Club_Start_Epoch INTEGER,
        Default_Session_Hour INTEGER NOT NULL DEFAULT 19,
        Default_Session_Minute INTEGER NOT NULL DEFAULT 30,
        Floor_Manager_Player_Id INTEGER,
        Floor_Manager_Table_Id INTEGER,
        Floor_Manager_Seat_Number INTEGER,
        Current_Game_Epoch INTEGER,
        Clock_Offset_Seconds INTEGER DEFAULT 0
    )
  ''');

  // Add Clock_Offset_Seconds column if upgrading an existing database — must run before INSERT
  try {
    await _database!.execute('ALTER TABLE System_State ADD COLUMN Clock_Offset_Seconds INTEGER DEFAULT 0');
    print('✓ Migrated System_State: added Clock_Offset_Seconds column');
  } catch (_) {
    // Column already exists — expected on fresh start or after first migration
  }

  await _database!.execute('''
    INSERT OR IGNORE INTO System_State (Id, Is_Club_Open, Current_Game_Epoch, Clock_Offset_Seconds)
    VALUES (1, 0, strftime('%s', 'now'), 0)
  ''');

  return _database!;
}
