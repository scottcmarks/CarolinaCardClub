// lib/providers/database_provider.dart

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/payment.dart';
import '../models/player.dart';
import '../models/player_category.dart';
import '../models/player_selection_item.dart';
import '../models/rate.dart';
import '../models/rate_interval.dart';
import '../models/session.dart';
import '../models/session_panel_item.dart';
import 'app_settings_provider.dart';

// Enum for tracking the state of the database loading process.
enum DatabaseLoadStatus {
  initial,
  loadingRemote,
  loadingAssets,
  loaded,
  error,
}

class DatabaseProvider with ChangeNotifier {
  static final DatabaseProvider _instance = DatabaseProvider._internal();
  static Database? _database;

  final String _databaseName = "CarolinaCardClub.db";
  String _currentRemoteDbUrl = "https://carolinacardclub.com/CarolinaCardClub.db";

  AppSettingsProvider? _appSettingsProvider;
  VoidCallback? _settingsListener;

  AsyncMemoizer<Database> _initDbMemoizer = AsyncMemoizer<Database>();

  DatabaseLoadStatus _loadStatus = DatabaseLoadStatus.initial;
  DatabaseLoadStatus get loadStatus => _loadStatus;

  DatabaseProvider._internal();

  factory DatabaseProvider() => _instance;

  // --- App Settings Integration ---

  void injectAppSettingsProvider(AppSettingsProvider provider) {
    if (_appSettingsProvider == provider) return;

    _appSettingsProvider?.removeListener(_settingsListener!);

    _appSettingsProvider = provider;
    _currentRemoteDbUrl = _appSettingsProvider!.currentSettings.remoteDatabaseUrl;
    _subscribeToAppSettings();

    if (_loadStatus == DatabaseLoadStatus.initial) {
      _triggerInitialLoad();
    }
  }

  void _subscribeToAppSettings() {
    _settingsListener = () {
      final newRemoteDbUrl = _appSettingsProvider!.currentSettings.remoteDatabaseUrl;
      if (newRemoteDbUrl != _currentRemoteDbUrl) {
        _currentRemoteDbUrl = newRemoteDbUrl;
        debugPrint("Remote database URL changed. Reloading database.");
        _reloadDatabase();
      }
    };
    _appSettingsProvider!.addListener(_settingsListener!);
  }

  Future<void> _triggerInitialLoad() async {
    try {
      await database;
    } catch (e) {
      debugPrint("Initial database load failed: $e");
      _setLoadStatus(DatabaseLoadStatus.error);
    }
  }

  Future<void> _reloadDatabase() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
    _initDbMemoizer = AsyncMemoizer<Database>();

    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);
    File dbFile = File(path);
    if (await dbFile.exists()) {
      await dbFile.delete();
      debugPrint("Existing database file deleted for reload.");
    }

    // Trigger the re-initialization
    await database;
  }

  @override
  void dispose() {
    _appSettingsProvider?.removeListener(_settingsListener!);
    _database?.close();
    super.dispose();
  }

  // --- Database Initialization and Management ---

  Future<Database> get database async {
    if (_database == null || !_database!.isOpen) {
      _database = await _initDbMemoizer.runOnce(() => _initDatabase());
    }
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);

    if (!await File(path).exists()) {
      try {
        _setLoadStatus(DatabaseLoadStatus.loadingRemote);
        await _downloadDatabase(path);
      } catch (e) {
        debugPrint("Database download failed: $e. Copying from assets.");
        _setLoadStatus(DatabaseLoadStatus.loadingAssets);
        await _copyDatabaseFromAssets(path);
      }
    }

    final db = await openDatabase(path, version: 1);
    _setLoadStatus(DatabaseLoadStatus.loaded);
    return db;
  }

  Future<void> _downloadDatabase(String path) async {
    final response = await http.get(Uri.parse(_currentRemoteDbUrl)).timeout(const Duration(seconds: 30));
    if (response.statusCode == 200) {
      await File(path).writeAsBytes(response.bodyBytes);
      debugPrint("Database downloaded successfully.");
    } else {
      throw Exception('Failed to download database: ${response.statusCode}');
    }
  }

  Future<void> _copyDatabaseFromAssets(String path) async {
    ByteData data = await rootBundle.load("assets/$_databaseName");
    List<int> bytes = data.buffer.asUint8List();
    await File(path).writeAsBytes(bytes);
    debugPrint("Database copied from assets successfully.");
  }

  void _setLoadStatus(DatabaseLoadStatus status) {
    if (_loadStatus != status) {
      _loadStatus = status;
      notifyListeners();
    }
  }

  Future<Database> ensure_db() async {
    return await database;
  }

  // --- CRUD Operations for Player ---

  Future<int> addPlayer(Player player) async {
    final db = await ensure_db();
    return await db.insert('Player', player.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Player?> getPlayer(int id) async {
    final db = await ensure_db();
    final List<Map<String, dynamic>> maps = await db.query('Player', where: 'Player_Id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return Player.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Player>> getAllPlayers() async {
    final db = await ensure_db();
    final List<Map<String, dynamic>> maps = await db.query('Player', orderBy: 'Name ASC');
    return List.generate(maps.length, (i) => Player.fromMap(maps[i]));
  }

  Future<int> updatePlayer(Player player) async {
    final db = await ensure_db();
    return await db.update('Player', player.toMap(), where: 'Player_Id = ?', whereArgs: [player.playerId]);
  }

  Future<int> deletePlayer(int id) async {
    final db = await ensure_db();
    return await db.delete('Player', where: 'Player_Id = ?', whereArgs: [id]);
  }

  // --- CRUD Operations for Payment ---

  Future<int> addPayment(Payment payment) async {
    final db = await ensure_db();
    // Use the model's toMap() method for consistency. This relies on the
    // Payment model to correctly map its properties to database columns.
    final id = await db.insert('Payment', payment.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    notifyListeners();
    return id;
  }

  Future<Payment?> getPayment(int id) async {
    final db = await ensure_db();
    final List<Map<String, dynamic>> maps = await db.query('Payment', where: 'Payment_Id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return Payment.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Payment>> getAllPayments() async {
    final db = await ensure_db();
    final List<Map<String, dynamic>> maps = await db.query('Payment', orderBy: 'Epoch DESC');
    return List.generate(maps.length, (i) => Payment.fromMap(maps[i]));
  }

  Future<List<Payment>> getPaymentsForPlayer(int playerId) async {
    final db = await ensure_db();
    final List<Map<String, dynamic>> maps = await db.query('Payment', where: 'Player_Id = ?', whereArgs: [playerId], orderBy: 'Epoch DESC');
    return List.generate(maps.length, (i) => Payment.fromMap(maps[i]));
  }

  Future<int> updatePayment(Payment payment) async {
    final db = await ensure_db();
    final id = await db.update('Payment', payment.toMap(), where: 'Payment_Id = ?', whereArgs: [payment.paymentId]);
    notifyListeners();
    return id;
  }

  Future<int> deletePayment(int id) async {
    final db = await ensure_db();
    final result = await db.delete('Payment', where: 'Payment_Id = ?', whereArgs: [id]);
    notifyListeners();
    return result;
  }

  // --- CRUD Operations for Session ---

  Future<int> addSession(Session session) async {
    final db = await ensure_db();
    final id = await db.insert('Session', session.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    notifyListeners();
    return id;
  }

  Future<Session?> getSession(int id) async {
    final db = await ensure_db();
    final List<Map<String, dynamic>> maps = await db.query('Session', where: 'Session_Id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return Session.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Session>> getAllSessions() async {
    final db = await ensure_db();
    final List<Map<String, dynamic>> maps = await db.query('Session', orderBy: 'Start_Epoch DESC');
    return List.generate(maps.length, (i) => Session.fromMap(maps[i]));
  }

  Future<int> updateSession(Session session) async {
    final db = await ensure_db();
    final id = await db.update('Session', session.toMap(), where: 'Session_Id = ?', whereArgs: [session.sessionId]);
    notifyListeners();
    return id;
  }

  Future<int> deleteSession(int id) async {
    final db = await ensure_db();
    final result = await db.delete('Session', where: 'Session_Id = ?', whereArgs: [id]);
    notifyListeners();
    return result;
  }

  // --- CRUD Operations for Player_Category ---
  Future<int> addPlayerCategory(PlayerCategory playerCategory) async {
    final db = await ensure_db();
    return await db.insert('Player_Category', playerCategory.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }
  Future<List<PlayerCategory>> getAllPlayerCategories() async {
    final db = await ensure_db();
    final List<Map<String, dynamic>> maps = await db.query('Player_Category');
    return List.generate(maps.length, (i) => PlayerCategory.fromMap(maps[i]));
  }
  Future<PlayerCategory?> getPlayerCategory(int id) async {
    final db = await ensure_db();
    final List<Map<String, dynamic>> maps = await db.query('Player_Category', where: 'Player_Category_Id = ?', whereArgs: [id]);
    return maps.isNotEmpty ? PlayerCategory.fromMap(maps.first) : null;
  }
  Future<int> updatePlayerCategory(PlayerCategory playerCategory) async {
    final db = await ensure_db();
    return await db.update('Player_Category', playerCategory.toMap(), where: 'Player_Category_Id = ?', whereArgs: [playerCategory.playerCategoryId]);
  }
  Future<int> deletePlayerCategory(int id) async {
    final db = await ensure_db();
    return await db.delete('Player_Category', where: 'Player_Category_Id = ?', whereArgs: [id]);
  }

  // --- CRUD Operations for Rate ---
  Future<int> addRate(Rate rate) async {
    final db = await ensure_db();
    return await db.insert('Rate', rate.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }
  Future<List<Rate>> getAllRates() async {
    final db = await ensure_db();
    final List<Map<String, dynamic>> maps = await db.query('Rate');
    return List.generate(maps.length, (i) => Rate.fromMap(maps[i]));
  }
  Future<Rate?> getRate(int id) async {
    final db = await ensure_db();
    final List<Map<String, dynamic>> maps = await db.query('Rate', where: 'Rate_Id = ?', whereArgs: [id]);
    return maps.isNotEmpty ? Rate.fromMap(maps.first) : null;
  }
  Future<int> updateRate(Rate rate) async {
    final db = await ensure_db();
    return await db.update('Rate', rate.toMap(), where: 'Rate_Id = ?', whereArgs: [rate.rateId]);
  }
  Future<int> deleteRate(int id) async {
    final db = await ensure_db();
    return await db.delete('Rate', where: 'Rate_Id = ?', whereArgs: [id]);
  }

  // --- CRUD Operations for Rate_Interval ---
  Future<int> addRateInterval(RateInterval rateInterval) async {
    final db = await ensure_db();
    return await db.insert('Rate_Interval', rateInterval.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }
  Future<List<RateInterval>> getAllRateIntervals() async {
    final db = await ensure_db();
    final List<Map<String, dynamic>> maps = await db.query('Rate_Interval');
    return List.generate(maps.length, (i) => RateInterval.fromMap(maps[i]));
  }
  Future<RateInterval?> getRateInterval(int id) async {
    final db = await ensure_db();
    final List<Map<String, dynamic>> maps = await db.query('Rate_Interval', where: 'Rate_Interval_Id = ?', whereArgs: [id]);
    return maps.isNotEmpty ? RateInterval.fromMap(maps.first) : null;
  }
  Future<int> updateRateInterval(RateInterval rateInterval) async {
    final db = await ensure_db();
    return await db.update('Rate_Interval', rateInterval.toMap(), where: 'Rate_Interval_Id = ?', whereArgs: [rateInterval.rateIntervalId]);
  }
  Future<int> deleteRateInterval(int id) async {
    final db = await ensure_db();
    return await db.delete('Rate_Interval', where: 'Rate_Interval_Id = ?', whereArgs: [id]);
  }

  // --- Existing Read-Only Operations from Views ---

  Future<List<PlayerSelectionItem>> fetchPlayerSelectionList () async {
    final db = await ensure_db();
    final List<Map<String, dynamic>> maps = await db.query('Player_Selection_List');
    return List.generate(maps.length, (i) => PlayerSelectionItem.fromMap(maps[i]));
  }

  Future<List<SessionPanelItem>> fetchSessionPanelList({
    bool showOnlyActiveSessions = true,
    int? playerId,
  }) async {
    final db = await ensure_db();
    String? whereClause;
    List<dynamic>? whereArgs;

    if (showOnlyActiveSessions && playerId != null) {
      whereClause = 'Player_Id = ? AND Stop_Epoch IS NULL';
      whereArgs = [playerId];
    } else if (showOnlyActiveSessions) {
      whereClause = 'Stop_Epoch IS NULL';
    } else if (playerId != null) {
      whereClause = 'Player_Id = ?';
      whereArgs = [playerId];
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'Session_Panel_List',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'Stop_Epoch ASC, Name ASC',
    );
    return List.generate(maps.length, (i) => SessionPanelItem.fromMap(maps[i]));
  }
}
