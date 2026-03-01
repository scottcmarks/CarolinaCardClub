// server/bin/carolina_card_club_server.dart

import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;

// Package import for shared constants/models
import 'package:shared/shared.dart';

// Constants for better readability
const httpOK = 200;
const httpCreated = 201;
const httpForbidden = 403;
const httpNotFound = 404;
const httpError = 500;

Database? _database;

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final router = Router();

  // 1. Data Retrieval Handlers
  router.get('/players/selection', _getPlayersHandler);
  router.get('/sessions/panel', _getSessionsHandler);
  router.get('/state', _getStateHandler);
  router.get('/tables', _getTablesHandler);

  // 2. Action Handlers
  router.post('/sessions', _addSessionHandler);
  router.post('/sessions/stop', _stopSessionHandler);
  router.post('/sessions/move', _moveSessionHandler);
  router.post('/payments', _addPaymentHandler);
  router.post('/state/toggle', _toggleStateHandler);
  router.post('/tables/toggle', _toggleTableHandler);
  router.post('/state/defaults', _updateDefaultsHandler); // NEW: Update Hour/Minute

  // 3. Maintenance Handlers
  router.post('/maintenance/backup', _manualBackupHandler);
  router.post('/maintenance/restore', _manualRestoreHandler);
  router.post('/system/reload', _manualReloadHandler);

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
    print('✓ Database: ${Shared.dbFileName}');
    print('✓ Remote Vault: ${Shared.remoteServerBaseUrl}/${Shared.remoteDbHandlerPath}');
    print('====================================================');
  } catch (e) {
    print('CRITICAL STARTUP ERROR: $e');
  }
}

// --- DATA RETRIEVAL HANDLERS ---

Future<Response> _getPlayersHandler(Request request) async {
  try {
    final db = await _db;
    final results = await db.query('Player_Selection_List');
    return Response.ok(json.encode(results), headers: {'Content-Type': 'application/json'});
  } catch (e) {
    return Response.internalServerError(body: '$e');
  }
}

Future<Response> _getSessionsHandler(Request request) async {
  try {
    final db = await _db;
    final results = await db.query('Session_Panel_List');
    return Response.ok(json.encode(results), headers: {'Content-Type': 'application/json'});
  } catch (e) {
    return Response.internalServerError(body: '$e');
  }
}

Future<Response> _getStateHandler(Request request) async {
  try {
    final db = await _db;
    final results = await db.query('System_State', where: 'Id = ?', whereArgs: [1]);
    if (results.isEmpty) return Response(httpNotFound, body: 'State not initialized');
    return Response.ok(json.encode(results.first), headers: {'Content-Type': 'application/json'});
  } catch (e) {
    return Response.internalServerError(body: '$e');
  }
}

Future<Response> _getTablesHandler(Request request) async {
  try {
    final db = await _db;
    final results = await db.query('PokerTable');
    return Response.ok(json.encode(results), headers: {'Content-Type': 'application/json'});
  } catch (e) {
    return Response.internalServerError(body: '$e');
  }
}

// --- ACTION HANDLERS ---

Future<Response> _addSessionHandler(Request request) async {
  try {
    final data = json.decode(await request.readAsString());
    final db = await _db;

    // Safely extract the Player_Id whether the client sent camelCase or Pascal_Snake_Case
    final int playerId = data['playerId'] ?? data['Player_Id'];

    final active = await db.query('Session',
      where: 'Player_Id = ? AND Stop_Epoch IS NULL',
      whereArgs: [playerId]
    );
    if (active.isNotEmpty) {
      return Response(httpForbidden, body: json.encode({'error': 'Player already has an active session'}));
    }

    // Explicitly map the incoming JSON to exact SQLite column names
    final Map<String, dynamic> insertData = {
      'Player_Id': playerId,
      'Start_Epoch': data['startEpoch'] ?? data['Start_Epoch'],
      'PokerTable_Id': data['pokerTableId'] ?? data['PokerTable_Id'],
      'Seat_Number': data['seatNumber'] ?? data['Seat_Number'],
      // SQLite uses 1 for true, 0 for false
      'Is_Prepaid': (data['isPrepaid'] == true || data['Is_Prepaid'] == 1) ? 1 : 0,
      'Prepay_Amount': data['prepayAmount'] ?? data['Prepay_Amount'] ?? 0,
    };

    // Insert into the database using the strictly mapped data
    await db.insert('Session', insertData);

    return Response.ok(json.encode({'success': true}));
  } catch (e) {
    print('🛑 ERROR [_addSessionHandler]: $e');
    return Response.internalServerError(body: '$e');
  }
}

Future<Response> _stopSessionHandler(Request request) async {
  try {
    final data = json.decode(await request.readAsString());

    // Safely extract keys
    final int sessionId = data['sessionId'] ?? data['Session_Id'];
    final int stopEpoch = data['stopEpoch'] ?? data['Stop_Epoch'];

    final db = await _db;

    int count = await db.update(
      'Session',
      {'Stop_Epoch': stopEpoch},
      where: 'Session_Id = ?',
      whereArgs: [sessionId]
    );

    if (count == 0) return Response(httpNotFound, body: 'Session not found');

    return Response.ok(json.encode({'success': true}));
  } catch (e) {
    print('🛑 ERROR [_stopSessionHandler]: $e');
    return Response.internalServerError(body: '$e');
  }
}

Future<Response> _moveSessionHandler(Request request) async {
  try {
    final data = json.decode(await request.readAsString());

    final int sessionId = data['sessionId'] ?? data['Session_Id'];
    final int newTableId = data['pokerTableId'] ?? data['PokerTable_Id'];
    final int newSeatNumber = data['seatNumber'] ?? data['Seat_Number'];

    final db = await _db;

    int count = await db.update(
      'Session',
      {
        'PokerTable_Id': newTableId,
        'Seat_Number': newSeatNumber
      },
      where: 'Session_Id = ?',
      whereArgs: [sessionId]
    );

    if (count == 0) return Response(httpNotFound, body: 'Session not found');

    return Response.ok(json.encode({'success': true}));
  } catch (e) {
    print('🛑 ERROR [_moveSessionHandler]: $e');
    return Response.internalServerError(body: '$e');
  }
}

Future<Response> _addPaymentHandler(Request request) async {
  try {
    final data = json.decode(await request.readAsString());

    // Safely extract keys and enforce integer types
    final int amount = ((data['amount'] ?? data['Amount']) as num).round();
    final int playerId = data['playerId'] ?? data['Player_Id'];
    final int epoch = data['epoch'] ?? data['Epoch'] ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);

    final db = await _db;

    await db.insert('Payment', {
      'Player_Id': playerId,
      'Amount': amount,
      'Epoch': epoch
    });

    return Response.ok(json.encode({'success': true}));
  } catch (e) {
    print('🛑 ERROR [_addPaymentHandler]: $e');
    return Response.internalServerError(body: '$e');
  }
}

Future<Response> _toggleStateHandler(Request request) async {
  try {
    final data = json.decode(await request.readAsString());

    // Safely extract keys
    final bool isOpen = data['isClubOpen'] == true || data['Is_Club_Open'] == 1 || data['Is_Club_Open'] == true;
    final int? epoch = data['clubStartEpoch'] ?? data['Club_Start_Epoch'];

    final db = await _db;
    await db.update('System_State',
      {'Is_Club_Open': isOpen ? 1 : 0, 'Club_Start_Epoch': epoch},
      where: 'Id = ?', whereArgs: [1]
    );

    return Response.ok(json.encode({'success': true}));
  } catch (e) {
    return Response.internalServerError(body: '$e');
  }
}

Future<Response> _toggleTableHandler(Request request) async {
  try {
    final data = json.decode(await request.readAsString());

    final int tableId = data['pokerTableId'] ?? data['PokerTable_Id'];
    final bool isActive = data['isActive'] == true || data['IsActive'] == 1 || data['IsActive'] == true;

    final db = await _db;

    int count = await db.update(
      'PokerTable',
      {'IsActive': isActive ? 1 : 0},
      where: 'PokerTable_Id = ?',
      whereArgs: [tableId]
    );

    if (count == 0) return Response(httpNotFound, body: 'Table not found');

    return Response.ok(json.encode({'success': true}));
  } catch (e) {
    print('🛑 ERROR [_toggleTableHandler]: $e');
    return Response.internalServerError(body: '$e');
  }
}

// NEW: Update default session start time
Future<Response> _updateDefaultsHandler(Request request) async {
  try {
    final data = json.decode(await request.readAsString());
    final int hour = data['hour'] ?? 19;
    final int minute = data['minute'] ?? 30;

    final db = await _db;
    await db.update('System_State',
      {
        'Default_Session_Hour': hour,
        'Default_Session_Minute': minute
      },
      where: 'Id = ?', whereArgs: [1]
    );

    return Response.ok(json.encode({'success': true}));
  } catch (e) {
    print('🛑 ERROR [_updateDefaultsHandler]: $e');
    return Response.internalServerError(body: '$e');
  }
}

// --- MAINTENANCE & REFRESH ---

Future<Response> _manualReloadHandler(Request request) async {
  try {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    await _db;
    return Response.ok(json.encode({'status': 'reloaded', 'httpCode': httpOK}));
  } catch (e) {
    return Response.internalServerError(body: 'Reload failed: $e');
  }
}

Future<Response> _manualBackupHandler(Request request) async {
  try {
    final data = json.decode(await request.readAsString());
    if (data['apiKey'] != Shared.remoteApiKey) return Response(httpForbidden, body: 'Invalid Key');

    final dbFile = File(p.join(Directory.current.path, Shared.dbFileName));
    if (!await dbFile.exists()) return Response(httpNotFound, body: 'Local DB not found');

    final String fullUrl = '${Shared.remoteServerBaseUrl}/${Shared.remoteDbHandlerPath}';
    final uri = Uri.parse(fullUrl);
    final httpRequest = http.MultipartRequest('POST', uri)
      ..fields['apiKey'] = Shared.remoteApiKey
      ..files.add(await http.MultipartFile.fromPath('database', dbFile.path));

    final streamedResponse = await httpRequest.send();

    if (streamedResponse.statusCode == httpOK) {
      return Response.ok(json.encode({'success': true, 'message': 'Backup pushed to remote server'}));
    }
    return Response(httpError, body: 'Remote server rejected backup. Status: ${streamedResponse.statusCode}');
  } catch (e) {
    return Response.internalServerError(body: 'Backup process failed: $e');
  }
}

Future<Response> _manualRestoreHandler(Request request) async {
  try {
    final data = json.decode(await request.readAsString());
    if (data['apiKey'] != Shared.remoteApiKey) return Response(httpForbidden, body: 'Invalid Key');

    final String fullUrl = '${Shared.remoteServerBaseUrl}/${Shared.remoteDbHandlerPath}';
    final response = await http.get(Uri.parse("$fullUrl?apiKey=${Shared.remoteApiKey}"));

    if (response.statusCode == httpOK) {
      if (_database != null) await _database!.close();
      _database = null;

      final dbPath = p.join(Directory.current.path, Shared.dbFileName);
      await File(dbPath).writeAsBytes(response.bodyBytes);

      await _db;
      return Response.ok(json.encode({'success': true, 'message': 'Database restored and reloaded'}));
    }
    return Response(httpError, body: 'Failed to fetch backup from remote. Status: ${response.statusCode}');
  } catch (e) {
    return Response.internalServerError(body: 'Restore process failed: $e');
  }
}

// --- MIDDLEWARES ---

Middleware get _authMiddleware => (innerHandler) {
  return (request) {
    if (request.method == 'OPTIONS') return innerHandler(request);
    if (request.headers['x-api-key'] != Shared.defaultLocalApiKey) {
      return Response(httpForbidden, body: 'Invalid or missing x-api-key');
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

// --- DATABASE & MIGRATION ---

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
        Floor_Manager_Seat_Number INTEGER
    )
  ''');

  await _database!.execute('''
    INSERT OR IGNORE INTO System_State (Id, Is_Club_Open) VALUES (1, 0)
  ''');

  return _database!;
}