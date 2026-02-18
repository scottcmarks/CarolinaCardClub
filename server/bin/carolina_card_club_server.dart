// server/bin/carolina_card_club_server.dart

import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;

// Corrected package import
import 'package:shared/shared.dart';

Database? _database;

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final router = Router();

  // 1. Data Retrieval Handlers
  router.get('/players/selection', _getPlayersHandler);
  router.get('/sessions/panel', _getSessionsHandler);

  // 2. Action Handlers
  router.post('/sessions', _addSessionHandler);
  router.post('/sessions/stop', _stopSessionHandler);
  router.post('/payments', _addPaymentHandler);

  // 3. Maintenance Handlers
  router.post('/maintenance/backup', _manualBackupHandler);
  router.post('/maintenance/restore', _manualRestoreHandler);

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_corsMiddleware)
      .addMiddleware(_authMiddleware)
      .addHandler(router);

  try {
    // Reference Shared for port
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

// --- ACTION HANDLERS ---

Future<Response> _addSessionHandler(Request request) async {
  try {
    final data = json.decode(await request.readAsString());
    final db = await _db;
    await db.insert('Session', data);
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

    // Enforce Even Dollars rounding
    double hours = (stopEpoch - (s['Start_Epoch'] as int)) / Shared.secondsPerHour;
    int finalCost = (s['Is_Prepaid'] == 1)
        ? (s['Prepay_Amount'] as num).toInt()
        : (hours * (s['Hourly_Rate'] as num)).round();

    await db.transaction((txn) async {
      await txn.update('Session', {'Stop_Epoch': stopEpoch, 'Amount': finalCost}, where: 'Session_Id = ?', whereArgs: [sessionId]);
      await txn.execute('UPDATE Player SET Balance = Balance - ? WHERE Player_Id = ?', [finalCost, s['Player_Id']]);
    });

    return Response.ok(json.encode({'success': true, 'cost': finalCost}));
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

// --- MAINTENANCE HANDLERS ---

Future<Response> _manualBackupHandler(Request request) async {
  try {
    final data = json.decode(await request.readAsString());
    if (data['apiKey'] != Shared.remoteApiKey) return Response.forbidden('Invalid Key');
    // Implement cloud upload logic here
    return Response.ok(json.encode({'success': true}));
  } catch (e) {
    return Response.internalServerError(body: '$e');
  }
}

Future<Response> _manualRestoreHandler(Request request) async {
  try {
    final data = json.decode(await request.readAsString());
    if (data['apiKey'] != Shared.remoteApiKey) return Response.forbidden('Invalid Key');
    // Implement cloud download logic here
    return Response.ok(json.encode({'success': true}));
  } catch (e) {
    return Response.internalServerError(body: '$e');
  }
}

// --- MIDDLEWARES & HELPERS ---

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

Future<Database> get _db async {
  if (_database != null) return _database!;
  _database = await openDatabase(p.join(Directory.current.path, Shared.dbFileName));
  return _database!;
}