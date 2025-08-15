// main.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data'; // Import for ByteData
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

// AppDatabase (no changes needed)
class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  factory AppDatabase() => _instance;
  AppDatabase._internal();

  static Database? _database;
  static const String _databaseFileName = 'CarolinaCardClub.db';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseFileName);

    bool databaseExists = await File(path).exists();

    if (!databaseExists) {
      try {
        ByteData data = await rootBundle.load(join('assets', _databaseFileName));
        List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await File(path).writeAsBytes(bytes, flush: true);
        print("Database copied from assets to: $path");
      } catch (e) {
        print("Error copying database from assets: $e");
      }
    } else {
      print("Database already exists at: $path. Opening existing database.");
    }

    return await openDatabase(path, version: 1);
  }

  Future<List<Map<String, dynamic>>> fetchPlayerSelectionList() async {
    final db = await database;
    return await db.query('Player_Selection_List');
  }

  Future<List<Map<String, dynamic>>> fetchSessionPanelList({int? playerId}) async {
    final db = await database;
    if (playerId != null) {
      return await db.query(
        'Session_Panel_List',
        where: 'Player_Id = ?',
        whereArgs: [playerId],
        orderBy: 'Stop_Epoch ASC, Name ASC',
      );
    } else {
      return await db.query('Session_Panel_List', orderBy: 'Stop_Epoch ASC, Name ASC');
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dbHelper = AppDatabase();
  await dbHelper.database;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Carolina Card Club App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        textTheme: Theme.of(context).textTheme.copyWith(
              bodyLarge: const TextStyle(fontSize: 16.0),
              bodyMedium: const TextStyle(fontSize: 14.0),
            ),
      ),
      home: const MainSplitViewPage(),
    );
  }
}

class MainSplitViewPage extends StatefulWidget {
  const MainSplitViewPage({Key? key}) : super(key: key);

  @override
  State<MainSplitViewPage> createState() => _MainSplitViewPageState();
}

class _MainSplitViewPageState extends State<MainSplitViewPage> {
  late Future<List<Map<String, dynamic>>> _playerListData;
  late Future<List<Map<String, dynamic>>> _sessionPanelListData;
  int? _selectedPlayerId;

  @override
  void initState() {
    super.initState();
    _playerListData = AppDatabase().fetchPlayerSelectionList();
    _sessionPanelListData = AppDatabase().fetchSessionPanelList();
  }

  void _onPlayerSelected(int playerId) {
    setState(() {
      _selectedPlayerId = playerId;
      _sessionPanelListData = AppDatabase().fetchSessionPanelList(playerId: _selectedPlayerId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Players & Sessions'),
      ),
      body: Row(
        children: [
          // Left Pane: Player List
          Expanded(
            flex: 1,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _playerListData,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No players found.'));
                } else {
                  final data = snapshot.data!;
                  return ListView.builder(
                    itemCount: data.length,
                    itemBuilder: (context, index) {
                      final item = data[index];
                      final int playerId = item['Player_Id'];
                      final String playerName = item['Name'] ?? 'Unnamed';
                      final double? playerBalance = item['Balance'];

                      // Determine background color based on balance
                      Color? cardColor = _selectedPlayerId == playerId ? Colors.blue.shade100 : null;
                      if (playerBalance != null && playerBalance < 0) {
                        cardColor = Colors.red.shade100;
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        color: cardColor,
                        child: ListTile(
                          title: Text(playerName),
                          onTap: () => _onPlayerSelected(playerId),
                        ),
                      );
                    },
                  );
                }
              },
            ),
          ),
          const VerticalDivider(width: 1),

          // Right Pane: Session List
          Expanded(
            flex: 2,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _sessionPanelListData,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No sessions found for selected player or error.'));
                } else {
                  final data = snapshot.data!;
                  return ListView.builder(
                    itemCount: data.length,
                    itemBuilder: (context, index) {
                      final item = data[index];

                      final String name = item['Name'] ?? 'Unnamed';
                      final int? startEpoch = item['StartEpoch'];
                      final int? stopEpoch = item['Stop_Epoch'];
                      final double? amount = item['Amount'];
                      final double? balance = item['Balance'];

                      final String formattedStartTime = startEpoch != null
                          ? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(startEpoch * 1000))
                          : 'N/A';
                      final String formattedStopTime = stopEpoch != null
                          ? DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(stopEpoch * 1000))
                          : 'Ongoing';
                      final String formattedAmount = amount != null ? '\$${amount.toStringAsFixed(2)}' : '\$0.00';
                      final String formattedBalance = balance != null ? '\$${balance.toStringAsFixed(2)}' : '\$0.00';

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Balance: $formattedBalance',
                                    style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('$formattedStartTime - $formattedStopTime'),
                              // Changed text to "Amount:" and removed fontWeight
                              Text(
                                'Amount: $formattedAmount',
                                style: const TextStyle(fontSize: 18.0, color: Colors.green), // Removed fontWeight
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
