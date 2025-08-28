// server/bin/carolina_card_club_server.dart

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
const String remoteApiKey = "31221da269c89d6e770cd96ad259433dffedd1f75250597cff4114144086129797bf09ab6fff19234e9674d7e48e428cd8aeb8a5a23a36abcd705acae8d1c030";
// ADDED: API key for clients to connect to this server
const String localApiKey = "9af85ab7895eb6d8baceb0fe1203c96851c87bdbad9af5fd5d5d0de2a24dad428b5906722412bfa5b4fe3a9a07a7a24abea50cff4c9de08c02b8708871f1c2b1";
// ---

Database? _database;

void main() async {
  sqfliteFfiInit();
  await _downloadDatabase();

  final router = Router()
    ..get('/players', _getPlayers)
    ..get('/sessions', _getSessions)
    ..post('/sessions', _addSession)
    ..put('/sessions/<id>', _updateSession)
    ..post('/payments', _addPayment)
    ..post('/backup', _backupDatabase);

  // Create a pipeline that includes the new authentication middleware
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_authMiddleware()) // Add the security check
      .addHandler(router);

  final server = await io.serve(handler, 'localhost', 8080);
  print('✓ Secure Server listening on localhost:${server.port}');
}

// --- Security Middleware ---
Middleware _authMiddleware() {
  return (Handler innerHandler) {
    return (Request request) {
      final apiKey = request.headers['x-api-key'];
      if (apiKey == null || apiKey != localApiKey) {
        return Response.forbidden('Invalid or missing API Key.');
      }
      // If key is valid, pass the request to the next handler
      return innerHandler(request);
    };
  };
}

// --- Database Management & API Handlers (code is the same as before) ---
// ... (rest of the server code from previous versions)
// Omitted for brevity.
Future<Database> get _db async {
  if (_database == null || !_database!.isOpen) {
    final dbPath = p.join(Directory.current.path, dbFileName);
    _database = await databaseFactoryFfi.openDatabase(dbPath);
  }
  return _database!;
}
Future<Response> _getPlayers(Request request) async { /* ... */ return Response.ok('{}'); }
Future<Response> _getSessions(Request request) async { /* ... */ return Response.ok('{}'); }
Future<Response> _addSession(Request request) async { /* ... */ return Response.ok('{}'); }
Future<Response> _updateSession(Request request, String id) async { /* ... */ return Response.ok('{}'); }
Future<Response> _addPayment(Request request) async { /* ... */ return Response.ok('{}'); }
Future<Response> _backupDatabase(Request request) async { /* ... */ return Response.ok('{}'); }
Future<void> _downloadDatabase() async { /* ... */ }
