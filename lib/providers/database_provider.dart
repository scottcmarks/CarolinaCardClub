// lib/database_provider.dart (Updated with DatabaseLoadStatus)
import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Though Provider isn't directly used here, often needed for setup
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'dart:typed_data';

import 'package:async/async.dart'; // Import for AsyncMemoizer


import '../models/payment.dart';
import '../models/player.dart';
import '../models/player_category.dart';
import '../models/rate.dart';
import '../models/rate_interval.dart';
import '../models/session.dart';
import '../models/player_selection_item.dart';
import '../models/session_panel_item.dart';
import '../models/app_settings.dart';


import 'app_settings_provider.dart';

// Define the enum for database loading status
enum DatabaseLoadStatus {
  initial,        // Initial state before any load attempt
  loadingRemote,  // Attempting to download from remote URL
  loadingAssets,  // Falling back to copying from assets
  loaded,         // Database successfully loaded and open
  error,          // An error occurred during loading
}

class DatabaseProvider with ChangeNotifier {
  static final DatabaseProvider _instance = DatabaseProvider._internal();
  static Database? _database;

  final String _databaseName = "CarolinaCardClub.db";
  String _currentRemoteDbUrl = "https://carolinacardclub.com/CarolinaCardClub.db"; // Default

  AppSettingsProvider? _appSettingsProvider;
  VoidCallback? _settingsListener;

  AsyncMemoizer<Database> _initDbMemoizer = AsyncMemoizer<Database>();

  // Add the database loading status
  DatabaseLoadStatus _loadStatus = DatabaseLoadStatus.initial;
  DatabaseLoadStatus get loadStatus => _loadStatus;

  DatabaseProvider._internal() {
    _subscribeToAppSettings();
  }

  factory DatabaseProvider() => _instance;

  void injectAppSettingsProvider(AppSettingsProvider provider) {
    if (_appSettingsProvider == provider) return;

    if (_appSettingsProvider != null && _settingsListener != null) {
      _appSettingsProvider!.removeListener(_settingsListener!);
    }

    _appSettingsProvider = provider;
    _currentRemoteDbUrl = _appSettingsProvider!.currentSettings.remoteDatabaseUrl;
    _subscribeToAppSettings();
    // After injecting, immediately attempt to load settings from provider if not already loading
    if (_loadStatus == DatabaseLoadStatus.initial) {
      _triggerInitialLoad();
    }
  }

  void _subscribeToAppSettings() {
    if (_appSettingsProvider != null && _settingsListener != null) {
      _appSettingsProvider!.removeListener(_settingsListener!);
    }

    if (_appSettingsProvider != null) {
      _settingsListener = () {
        final newRemoteDbUrl = _appSettingsProvider!.currentSettings.remoteDatabaseUrl;
        if (newRemoteDbUrl != _currentRemoteDbUrl) {
          _currentRemoteDbUrl = newRemoteDbUrl;
          print("Remote database URL changed to: $_currentRemoteDbUrl. Reloading database.");
          _reloadDatabase();
        }
      };
      _appSettingsProvider!.addListener(_settingsListener!);
    }
  }

  // New method to trigger the initial database load, often called after injection
  Future<void> _triggerInitialLoad() async {
     // Ensure _loadStatus is set to an appropriate loading state if not already.
    if (_loadStatus != DatabaseLoadStatus.loaded && _loadStatus != DatabaseLoadStatus.loadingRemote && _loadStatus != DatabaseLoadStatus.loadingAssets) {
       _loadStatus = DatabaseLoadStatus.initial;
       notifyListeners();
    }
    try {
      await database; // Call the getter to initiate or await the load
      _loadStatus = DatabaseLoadStatus.loaded;
      notifyListeners();
    } catch (e) {
      print("Initial database load failed: $e");
      _loadStatus = DatabaseLoadStatus.error;
      notifyListeners();
    }
  }

  Future<Database> get database async {
    if (_database == null) {
      try {
        _database = await _initDbMemoizer.runOnce(() => _initDatabase());
        // Only set to loaded if successful and not already loaded
        if (_loadStatus != DatabaseLoadStatus.loaded) {
          _loadStatus = DatabaseLoadStatus.loaded;
          notifyListeners();
        }
      } catch (e) {
        _loadStatus = DatabaseLoadStatus.error;
        notifyListeners();
        rethrow; // Re-throw the error so the FutureBuilder can catch it
      }
    }
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);

    bool databaseExists = await File(path).exists();

    if (!databaseExists) {
      try {
        _loadStatus = DatabaseLoadStatus.loadingRemote; // Update status
        notifyListeners(); // Notify UI about remote download attempt
        await _downloadDatabase(path);
      } catch (e) {
        print("Database download failed: $e. Copying from assets.");
        _loadStatus = DatabaseLoadStatus.loadingAssets; // Update status
        notifyListeners(); // Notify UI about fallback to assets
        await _copyDatabaseFromAssets(path); // This could still throw an error
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
    print("Attempting to download database from $_currentRemoteDbUrl");
    // TODO: timeout in AppSettings
    final response = await http.get(Uri.parse(_currentRemoteDbUrl)).timeout(const Duration(seconds: 30));

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
    // No table creation needed if pre-populated database is used
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle schema migrations here (e.g., adding columns, modifying tables)
  }

  Future<void> _reloadDatabase() async {
    // Inform UI that a reload is starting
    _loadStatus = DatabaseLoadStatus.initial;
    notifyListeners();

    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }

    _initDbMemoizer = AsyncMemoizer<Database>(); // Reset the memoizer

    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);
    File dbFile = File(path);
    if (await dbFile.exists()) {
      await dbFile.delete();
      print("Existing database file deleted.");
    }

    try {
      // Trigger new initialization and wait for it
      _database = await _initDbMemoizer.runOnce(() => _initDatabase());
      _loadStatus = DatabaseLoadStatus.loaded;
      notifyListeners();
    } catch (e) {
      print("Database reload failed: $e");
      _loadStatus = DatabaseLoadStatus.error;
      notifyListeners();
      // Re-throw if you want the calling context (e.g., UI) to potentially catch it
      rethrow;
    }
  }

  @override
  void dispose() {
    if (_appSettingsProvider != null && _settingsListener != null) {
      _appSettingsProvider!.removeListener(_settingsListener!);
    }
    _database?.close();
    super.dispose();
  }

  // Helper method for accessing the database, ensuring it's open
  Future<Database> ensure_db() async {
    final db = await database;
    if (!db.isOpen) {
      // This case should ideally be covered by the loadStatus checks in UI,
      // but is a good safeguard for direct calls or race conditions.
      throw Exception("Database is not open for operation");
    }
    return db;
  }


  // --- CRUD Operations for Player_Category ---
  Future<int> insertPlayerCategory(PlayerCategory playerCategory) async {
    final db = await ensure_db();
    return await db.insert('Player_Category', playerCategory.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }
  Future<List<PlayerCategory>> getAllPlayerCategories() async {
    final db = await ensure_db();
    final List<Map<String, dynamic>> maps = await db.query('Player_Category');
    return List.generate(maps.length, (i) => PlayerCategory.fromMap(maps[i]));
  }
  Future<PlayerCategory?> getPlayerCategoryById(int id) async {
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
  Future<int> insertRate(Rate rate) async {
    final db = await ensure_db();
    return await db.insert('Rate', rate.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }
  Future<List<Rate>> getAllRates() async {
    final db = await ensure_db();
    final List<Map<String, dynamic>> maps = await db.query('Rate');
    return List.generate(maps.length, (i) => Rate.fromMap(maps[i]));
  }
  Future<Rate?> getRateById(int id) async {
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
  Future<int> insertRateInterval(RateInterval rateInterval) async {
    final db = await ensure_db();
    return await db.insert('Rate_Interval', rateInterval.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }
  Future<List<RateInterval>> getAllRateIntervals() async {
    final db = await ensure_db();
    final List<Map<String, dynamic>> maps = await db.query('Rate_Interval');
    return List.generate(maps.length, (i) => RateInterval.fromMap(maps[i]));
  }
  Future<RateInterval?> getRateIntervalById(int id) async {
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
  Future<List<PlayerSelectionItem>> fetchPlayerSelectionList () async {
    final db = await ensure_db();
    final List<Map<String, dynamic>> maps = await db.query('Player_Selection_List');
    return List.generate(maps.length, (i) {
      return PlayerSelectionItem.fromMap(maps[i]); // Convert each map to a PlayerSelectionItem
    });
  }


  Future<List<SessionPanelItem>> fetchSessionPanelList({bool showOnlyActiveSessions = true,
                                                        int? playerId}) async {
    final db = await ensure_db();
    final List<Map<String, dynamic>> maps =
      showOnlyActiveSessions
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
