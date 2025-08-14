import 'dart:async';
import 'package:flutter/services.dart' show rootBundle, ByteData;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, "CarolinaCardClub.db");

    // Check if the database exists
    if (!await databaseExists(path)) {
      // If it doesn't exist, copy it from assets
      ByteData data = await rootBundle.load(join("assets", "CarolinaCardClub.db"));
      List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(path).writeAsBytes(bytes, flush: true);
    }

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future _onCreate(Database db, int version) async {
    // No need to execute CREATE TABLE/VIEW statements here if you're pre-populating
    // the database, as they are already included in the .db file.
    // This method will only be called if a brand new database needs to be created
    // (e.g., if the user deletes the app data).
    // You could put your CREATE statements here as a fallback or for development.
  }


Future<List<Map<String, dynamic>>> getPlayerSelectionList() async {
    final db = await database;
    return await db.query('Player_Selection_List');
  }

  Future<List<Map<String, dynamic>>> getSessionPanelList() async {
    final db = await database;
    return await db.query('Session_Panel_List');
  }
}
