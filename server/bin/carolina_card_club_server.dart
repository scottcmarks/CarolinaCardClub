// server/bin/carolina_card_club_server.dart

import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

// Package import for shared constants/models
import 'package:shared/shared.dart';

Database? _database;

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final router = Router();

  // 1. Data Retrieval Handlers
  router.get('/players/selection', _getPlayersHandler);
  router.get('/sessions/panel', _getSessionsHandler);
  router.get('/state', _getStateHandler);

  // 2. Action Handlers
  router.post('/sessions', _addSessionHandler);
  router.post('/sessions/stop', _stopSessionHandler);
  router.post('/payments', _addPaymentHandler);
  router.post('/state/toggle', _toggleStateHandler);

  // 3. Maintenance Handlers
  router.post('/maintenance/backup', _manualBackupHandler);
  router.post('/maintenance/restore', _manualRestoreHandler);

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_corsMiddleware)
      .addMiddleware(_authMiddleware)
      .addHandler(router);

  try {
    final port = int.parse(Shared.defaultServerPort);
    await io.serve(handler, InternetAddress.anyIPv4, port);
    print('====================================================');
    print('✓ Carolina Card Club Server running on port $port');
    print('✓ Database: ${Shared.dbFileName}');
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
    if (results.isEmpty) return Response.notFound('State not initialized');
    return Response.ok(json.encode(results.first), headers: {'Content-Type': 'application/json'});
  } catch (e) {
    return Response.internalServerError(body: '$e');
  }
}

// --- ACTION HANDLERS ---

Future<Response> _addSessionHandler(Request request) async {
  try {
    final data = json.decode(await request.readAsString());
    final db = await _db;

    // DEFENSIVE: Block if player is already active
    final active = await db.query('Session',
      where: 'Player_Id = ? AND Stop_Epoch IS NULL',
      whereArgs: [data['Player_Id']]
    );
    if (active.isNotEmpty) {
      return Response.forbidden(json.encode({'error': 'Player already has an active session'}));
    }

    await db.transaction((txn) async {
      await txn.insert('Session', data);

      // PREPAID LEDGER: Charge the player immediately so the balance is $0 after the UI sends the payment
      if (data['Is_Prepaid'] == 1 || data['Is_Prepaid'] == true) {
        int prepayAmount = (data['Prepay_Amount'] as num).round();
        await txn.execute(
          'UPDATE Player SET Balance = Balance - ? WHERE Player_Id = ?',
          [prepayAmount, data['Player_Id']]
        );
      }
    });

    return Response.ok(json.encode({'success': true}));
  } catch (e) {
    return Response.internalServerError(body: '$e');
  }
}

Future<Response> _stopSessionHandler(Request request) async {
  try {
    final data = json.decode(await request.readAsString());
    final int sessionId = data['Session_Id'];
    final int stopEpoch = data['Stop_Epoch'];
    final db = await _db;

    final sessionRes = await db.rawQuery('''
      SELECT s.Start_Epoch, p.Player_Id, p.Hourly_Rate, s.Is_Prepaid, s.Prepay_Amount
      FROM Session s JOIN Player p ON s.Player_Id = p.Player_Id
      WHERE s.Session_Id = ?
    ''', [sessionId]);

    if (sessionRes.isEmpty) return Response.notFound('Session not found');
    final s = sessionRes.first;

    await db.transaction((txn) async {
      if (s['Is_Prepaid'] == 1) {
        // PREPAID: We charged them at the start. Just update the record details.
        int finalCost = (s['Prepay_Amount'] as num).round();
        await txn.update('Session', {'Stop_Epoch': stopEpoch, 'Amount': finalCost},
            where: 'Session_Id = ?', whereArgs: [sessionId]);
      } else {
        // HOURLY: Calculate final cost and deduct from player balance now
        double hours = (stopEpoch - (s['Start_Epoch'] as int)) / Shared.secondsPerHour;
        int finalCost = (hours * (s['Hourly_Rate'] as num)).round();

        await txn.update('Session', {'Stop_Epoch': stopEpoch, 'Amount': finalCost},
            where: 'Session_Id = ?', whereArgs: [sessionId]);
        await txn.execute('UPDATE Player SET Balance = Balance - ? WHERE Player_Id = ?',
            [finalCost, s['Player_Id']]);
      }
    });

    return Response.ok(json.encode({'success': true}));
  } catch (e) {
    return Response.internalServerError(body: '$e');
  }
}

Future<Response> _addPaymentHandler(Request request) async {
  try {
    final data = json.decode(await request.readAsString());
    final int amount = (data['Amount'] as num).round();
    final db = await _db;

    await db.transaction((txn) async {
      await txn.insert('Payment', data);
      await txn.execute('UPDATE Player SET Balance = Balance + ? WHERE Player_Id = ?', [amount, data['Player_Id']]);
    });

    return Response.ok(json.encode({'success': true}));
  } catch (e) {
    return Response.internalServerError(body: '$e');
  }
}

Future<Response> _toggleStateHandler(Request request) async {
  try {
    final data = json.decode(await request.readAsString());
    final bool isOpen = data['Is_Club_Open'] == 1 || data['Is_Club_Open'] == true;
    final int? epoch = data['Club_Start_Epoch'];

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

// --- MAINTENANCE ---

Future<Response> _manualBackupHandler(Request request) async {
  final data = json.decode(await request.readAsString());
  if (data['apiKey'] != Shared.remoteApiKey) return Response.forbidden('Invalid Key');
  return Response.ok(json.encode({'success': true}));
}

Future<Response> _manualRestoreHandler(Request request) async {
  final data = json.decode(await request.readAsString());
  if (data['apiKey'] != Shared.remoteApiKey) return Response.forbidden('Invalid Key');
  return Response.ok(json.encode({'success': true}));
}

// --- MIDDLEWARES ---

Middleware get _authMiddleware => (innerHandler) {
  return (request) {
    if (request.method == 'OPTIONS') return innerHandler(request);
    if (request.headers['x-api-key'] != Shared.defaultLocalApiKey) {
      return Response.forbidden('Invalid or missing x-api-key');
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

  // Initialize System_State table
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

  // Ensure default row exists
  await _database!.execute('''
    INSERT OR IGNORE INTO System_State (Id, Is_Club_Open) VALUES (1, 0)
  ''');

  return _database!;
}