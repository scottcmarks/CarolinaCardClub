import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;

// --- Configuration ---
const String dbFileName = 'CarolinaCardClub.db';
const String downloadUrl = 'https://carolinacardclub.com/db_handler.php';
const String uploadUrl = 'https://carolinacardclub.com/db_handler.php';
const String secretApiKey = "31221da269c89d6e770cd96ad259433dffedd1f75250597cff4114144086129797bf09ab6fff19234e9674d7e48e428cd8aeb8a5a23a36abcd705acae8d1c030";
// ---

// Global database object
Database? _database;

// --- Main Server Setup ---
void main() async {
  // Initialize FFI for sqflite on desktop
  sqfliteFfiInit();

  // Download the database on startup
  await _downloadDatabase();

  // Create the router and define API endpoints
  final router = Router()
    ..get('/players', _getPlayers)
    ..get('/sessions', _getSessions)
    ..post('/sessions', _addSession)
    ..put('/sessions/<id>', _updateSession)
    ..post('/payments', _addPayment)
    ..post('/backup', _backupDatabase); // New endpoint to trigger a backup

  // Create a pipeline with logging
  final handler = const Pipeline().addMiddleware(logRequests()).addHandler(router);

  // Start the server
  final server = await io.serve(handler, 'localhost', 8080);
  print('✓ Server listening on localhost:${server.port}');
}

// --- Database Management ---
Future<Database> get _db async {
  if (_database == null || !_database!.isOpen) {
    final dbPath = p.join(Directory.current.path, dbFileName);
    _database = await databaseFactoryFfi.openDatabase(dbPath);
  }
  return _database!;
}

Future<void> _downloadDatabase() async {
  print('--- Initializing: Downloading database ---');
  final dbFile = File(p.join(Directory.current.path, dbFileName));
  try {
    final response = await http.get(Uri.parse(downloadUrl));
    if (response.statusCode == 200) {
      await dbFile.writeAsBytes(response.bodyBytes);
      print('✓ Database download complete.');
    } else {
      print('✗ Error downloading database. Status: ${response.statusCode}');
      exit(1);
    }
  } catch (e) {
    print('✗ An error occurred during download: $e');
    exit(1);
  }
}

// --- API Endpoint Handlers ---

// GET /players
Future<Response> _getPlayers(Request request) async {
  final db = await _db;
  final players = await db.query('Player_Selection_List');
  return Response.ok(jsonEncode(players), headers: {'Content-Type': 'application/json'});
}

// GET /sessions
Future<Response> _getSessions(Request request) async {
  final db = await _db;
  // This could be expanded with query parameters for filtering
  final sessions = await db.query('Session_Panel_List');
  return Response.ok(jsonEncode(sessions), headers: {'Content-Type': 'application/json'});
}

// POST /sessions
Future<Response> _addSession(Request request) async {
  final body = await request.readAsString();
  final sessionData = jsonDecode(body);
  final db = await _db;
  final id = await db.insert('Session', sessionData);
  return Response.ok(jsonEncode({'sessionId': id}));
}

// PUT /sessions/<id>
Future<Response> _updateSession(Request request, String id) async {
  final body = await request.readAsString();
  final sessionData = jsonDecode(body);
  final db = await _db;
  await db.update('Session', sessionData, where: 'Session_Id = ?', whereArgs: [id]);
  return Response.ok('Session updated');
}

// POST /payments
Future<Response> _addPayment(Request request) async {
  final body = await request.readAsString();
  final paymentData = jsonDecode(body);
  final db = await _db;
  final id = await db.insert('Payment', paymentData);
  return Response.ok(jsonEncode({'paymentId': id}));
}

// POST /backup
Future<Response> _backupDatabase(Request request) async {
  print('--- Backup requested ---');
  final dbPath = (await _db).path;

  // Temporarily close the DB to ensure file is not locked
  await _database?.close();
  _database = null;

  try {
    var req = http.MultipartRequest("POST", Uri.parse(uploadUrl))
      ..fields['apiKey'] = secretApiKey
      ..files.add(await http.MultipartFile.fromPath('database', dbPath, filename: dbFileName));

    var res = await req.send();

    if (res.statusCode == 200) {
      print('✓ Backup successful!');
      return Response.ok('Backup successful');
    } else {
      print('✗ Backup failed with status: ${res.statusCode}');
      return Response.internalServerError(body: 'Backup failed');
    }
  } catch (e) {
    print('✗ An error occurred during backup: $e');
    return Response.internalServerError(body: 'Backup error');
  } finally {
    // Re-open the database for the server to continue using
    await _db;
    print('✓ Database re-opened after backup.');
  }
}
