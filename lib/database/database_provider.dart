import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'dart:typed_data'; // Import for ByteData

// Import your data models
import 'package:carolina_card_club/models/payment.dart';
import 'package:carolina_card_club/models/player.dart';
import 'package:carolina_card_club/models/player_category.dart';
import 'package:carolina_card_club/models/rate.dart';
import 'package:carolina_card_club/models/rate_interval.dart';
import 'package:carolina_card_club/models/session.dart';
import 'package:carolina_card_club/models/player_selection_item.dart';
import 'package:carolina_card_club/models/session_panel_item.dart';

class DatabaseProvider with ChangeNotifier {
  static final DatabaseProvider _instance = DatabaseProvider._internal();
  static Database? _database;

  final String _databaseName = "CarolinaCardClub.db";
  final String _remoteDbUrl = "http://carolinacardclub.com/CarolinaCardClub.db";

  DatabaseProvider._internal();

  factory DatabaseProvider() => _instance;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);

    bool databaseExists = await File(path).exists();

    if (!databaseExists) {
      try {
        await _downloadDatabase(path);
      } catch (e) {
        print("Database download failed: $e. Copying from assets.");
        await _copyDatabaseFromAssets(path);
      }
    }

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _downloadDatabase(String path) async {
    print("Attempting to download database from $_remoteDbUrl");
    final response = await http.get(Uri.parse(_remoteDbUrl));

    if (response.statusCode == 200) {
      await File(path).writeAsBytes(response.bodyBytes);
      print("Database downloaded successfully.");
    } else {
      throw Exception('Failed to download database: ${response.statusCode}');
    }
  }

  Future<void> _copyDatabaseFromAssets(String path) async {
    print("Copying database from assets.");
    ByteData data = await rootBundle.load("assets/$_databaseName");
    List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await File(path).writeAsBytes(bytes);
    print("Database copied from assets successfully.");
  }

  Future<void> _onCreate(Database db, int version) async {
    //  No table creation needed if pre-populated database is used
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    //  Handle schema migrations here (e.g., adding columns, modifying tables)
    //  Example:
    // if (oldVersion < 2) {
    //   await db.execute("ALTER TABLE Player ADD COLUMN new_column TEXT");
    // }
  }

  // --- CRUD Operations for Player ---
  Future<int> insertPlayer(Player player) async {
    final db = await database;
    return await db.insert('Player', player.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }
  Future<List<Player>> getAllPlayers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('Player');
    return List.generate(maps.length, (i) => Player.fromMap(maps[i]));
  }
  Future<Player?> getPlayerById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('Player', where: 'Player_Id = ?', whereArgs: [id]);
    return maps.isNotEmpty ? Player.fromMap(maps.first) : null;
  }
  Future<int> updatePlayer(Player player) async {
    final db = await database;
    return await db.update('Player', player.toMap(), where: 'Player_Id = ?', whereArgs: [player.playerId]);
  }
  Future<int> deletePlayer(int id) async {
    final db = await database;
    return await db.delete('Player', where: 'Player_Id = ?', whereArgs: [id]);
  }

  // --- CRUD Operations for Session ---
  Future<int> insertSession(Session session) async {
    final db = await database;
    return await db.insert('Session', session.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }
  Future<List<Session>> getAllSessions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('Session');
    return List.generate(maps.length, (i) => Session.fromMap(maps[i]));
  }
  Future<Session?> getSessionById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('Session', where: 'Session_Id = ?', whereArgs: [id]);
    return maps.isNotEmpty ? Session.fromMap(maps.first) : null;
  }
  Future<int> updateSession(Session session) async {
    final db = await database;
    return await db.update('Session', session.toMap(), where: 'Session_Id = ?', whereArgs: [session.sessionId]);
  }
  Future<int> deleteSession(int id) async {
    final db = await database;
    return await db.delete('Session', where: 'Session_Id = ?', whereArgs: [id]);
  }

  // --- CRUD Operations for Payment ---
  Future<int> insertPayment(Payment payment) async {
    final db = await database;
    return await db.insert('Payment', payment.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }
  Future<List<Payment>> getAllPayments() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('Payment');
    return List.generate(maps.length, (i) => Payment.fromMap(maps[i]));
  }
  Future<Payment?> getPaymentById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('Payment', where: 'Payment_Id = ?', whereArgs: [id]);
    return maps.isNotEmpty ? Payment.fromMap(maps.first) : null;
  }
  Future<int> updatePayment(Payment payment) async {
    final db = await database;
    return await db.update('Payment', payment.toMap(), where: 'Payment_Id = ?', whereArgs: [payment.paymentId]);
  }
  Future<int> deletePayment(int id) async {
    final db = await database;
    return await db.delete('Payment', where: 'Payment_Id = ?', whereArgs: [id]);
  }

  // --- CRUD Operations for Player_Category ---
  Future<int> insertPlayerCategory(PlayerCategory playerCategory) async {
    final db = await database;
    return await db.insert('Player_Category', playerCategory.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }
  Future<List<PlayerCategory>> getAllPlayerCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('Player_Category');
    return List.generate(maps.length, (i) => PlayerCategory.fromMap(maps[i]));
  }
  Future<PlayerCategory?> getPlayerCategoryById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('Player_Category', where: 'Player_Category_Id = ?', whereArgs: [id]);
    return maps.isNotEmpty ? PlayerCategory.fromMap(maps.first) : null;
  }
  Future<int> updatePlayerCategory(PlayerCategory playerCategory) async {
    final db = await database;
    return await db.update('Player_Category', playerCategory.toMap(), where: 'Player_Category_Id = ?', whereArgs: [playerCategory.playerCategoryId]);
  }
  Future<int> deletePlayerCategory(int id) async {
    final db = await database;
    return await db.delete('Player_Category', where: 'Player_Category_Id = ?', whereArgs: [id]);
  }

  // --- CRUD Operations for Rate ---
  Future<int> insertRate(Rate rate) async {
    final db = await database;
    return await db.insert('Rate', rate.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }
  Future<List<Rate>> getAllRates() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('Rate');
    return List.generate(maps.length, (i) => Rate.fromMap(maps[i]));
  }
  Future<Rate?> getRateById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('Rate', where: 'Rate_Id = ?', whereArgs: [id]);
    return maps.isNotEmpty ? Rate.fromMap(maps.first) : null;
  }
  Future<int> updateRate(Rate rate) async {
    final db = await database;
    return await db.update('Rate', rate.toMap(), where: 'Rate_Id = ?', whereArgs: [rate.rateId]);
  }
  Future<int> deleteRate(int id) async {
    final db = await database;
    return await db.delete('Rate', where: 'Rate_Id = ?', whereArgs: [id]);
  }

  // --- CRUD Operations for Rate_Interval ---
  Future<int> insertRateInterval(RateInterval rateInterval) async {
    final db = await database;
    return await db.insert('Rate_Interval', rateInterval.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }
  Future<List<RateInterval>> getAllRateIntervals() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('Rate_Interval');
    return List.generate(maps.length, (i) => RateInterval.fromMap(maps[i]));
  }
  Future<RateInterval?> getRateIntervalById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('Rate_Interval', where: 'Rate_Interval_Id = ?', whereArgs: [id]);
    return maps.isNotEmpty ? RateInterval.fromMap(maps.first) : null;
  }
  Future<int> updateRateInterval(RateInterval rateInterval) async {
    final db = await database;
    return await db.update('Rate_Interval', rateInterval.toMap(), where: 'Rate_Interval_Id = ?', whereArgs: [rateInterval.rateIntervalId]);
  }
  Future<int> deleteRateInterval(int id) async {
    final db = await database;
    return await db.delete('Rate_Interval', where: 'Rate_Interval_Id = ?', whereArgs: [id]);
  }
  Future<List<PlayerSelectionItem>> fetchPlayerSelectionList() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('Player_Selection_List');
    return List.generate(maps.length, (i) {
      return PlayerSelectionItem.fromMap(maps[i]); // Convert each map to a PlayerSelectionItem
    });
  }
  Future<List<SessionPanelItem>> fetchSessionPanelList({bool showingOnlyActiveSessions = true,
                                                        int? playerId}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
      showingOnlyActiveSessions
      ? (
          (playerId != null)
          ? await db.query(
              'Session_Panel_List',
              where: 'Player_Id = ? AND Stop_Epoch IS NULL',
              whereArgs: [playerId],
              orderBy: 'Stop_Epoch ASC, Name ASC',
            )
          : await db.query(
              'Session_Panel_List',
              where: 'Stop_Epoch IS NULL',
              orderBy: 'Stop_Epoch ASC, Name ASC',
            )
        )
      : (
          (playerId != null)
          ? await db.query(
              'Session_Panel_List',
               where: 'Player_Id = ?',
               whereArgs: [playerId],
               orderBy: 'Stop_Epoch ASC, Name ASC',
            )
          : await db.query(
              'Session_Panel_List',
              orderBy: 'Stop_Epoch ASC, Name ASC',
            )
         );
    return List.generate(maps.length, (i) {
      return SessionPanelItem.fromMap(maps[i]); // Convert each map to a SessionPanelItem
    });
  }
}
