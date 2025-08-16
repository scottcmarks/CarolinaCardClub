// main.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data'; // Import for ByteData
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
// import 'package:path/path.dart';
import 'package:path/path.dart' as Path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'package:carolina_card_club/realtimeclock.dart';

import 'package:carolina_card_club/database/database_helper.dart'; // Adjust the path as needed
import 'package:carolina_card_club/models/player_selection_item.dart'; // Adjust the path as needed


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
    String path = Path.join(documentsDirectory.path, _databaseFileName);

    bool databaseExists = await File(path).exists();

    if (!databaseExists) {
      try {
        ByteData data = await rootBundle.load(Path.join('assets', _databaseFileName));
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
      return await db.query(
        'Session_Panel_List',
        where: 'Stop_Epoch IS NULL',
        orderBy: 'Stop_Epoch ASC, Name ASC',
      );
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
      title: 'Carolina Card Club',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        textTheme: Theme.of(context).textTheme.copyWith(
              bodyLarge: const TextStyle(fontSize: 16.0),
              bodyMedium: const TextStyle(fontSize: 14.0),
            ),
      ),
      home: MainSplitViewPage(
          sessionStartTime: DateTime.now()
      ),
    );
  }
}

class MainSplitViewPage extends StatefulWidget {
  final DateTime sessionStartTime;

//  const MainSplitViewPage({Key? key}) : super(key: key);
  MainSplitViewPage({required this.sessionStartTime});

@override
  State<MainSplitViewPage> createState() => _MainSplitViewPageState();
}
DateTime setDateTimeToSpecificTime(DateTime inputDate, DateTime inputTime) {
  return DateTime(
    inputDate.year,
    inputDate.month,
    inputDate.day,
    inputTime.hour,
    inputTime.minute,
    inputTime.second,
    inputTime.millisecond,
    inputTime.microsecond,
  );
}

// Define default session startup time as a top-level "constant" DateTime object
final DateTime _defaultSessionStartTime = DateTime(2000, 1, 1, 19, 30); // Date part doesn't mater

DateTime setTimeToDefaultSessionStartTime(DateTime inputDateTime) {
  return setDateTimeToSpecificTime(inputDateTime, _defaultSessionStartTime);
}


class _MainSplitViewPageState extends State<MainSplitViewPage> {
  // Change the type of _playerListData
  // late Future<List<Map<String, dynamic>>> _playerListData;
  late Future<List<PlayerSelectionItem>> _playerListData;
  late Future<List<Map<String, dynamic>>> _sessionPanelListData;

  late DateTime _currentSessionStartTime;
  int? _selectedPlayerId;

  @override
  void initState() {
    super.initState();
    _playerListData = DatabaseHelper().fetchPlayerSelectionList();  // AppDatabase().fetchPlayerSelectionList();
    _sessionPanelListData = AppDatabase().fetchSessionPanelList();
    _currentSessionStartTime = widget.sessionStartTime;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showStartTimeDialog(context);
    });
  }


  Future<void> _showStartTimeDialog(BuildContext context) async {
    // Step 1: Show the date picker
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(), // Sets the initial selected date to today
      firstDate: DateTime(2020),   // The earliest date a user can select
      lastDate: DateTime(2100),    // The latest date a user can select
    );

    // If a date was picked, proceed to pick the time
    if (pickedDate != null) {
      // Step 2: Show the time picker
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(setTimeToDefaultSessionStartTime(pickedDate)), // Default to picked day at 19:30
        helpText: 'Select Session Start Time',
        initialEntryMode: TimePickerEntryMode.input,
      );

      // If both date and time were picked, combine them
      if (pickedTime != null) {
        final DateTime selectedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        print('Selected Session Start date and time: $selectedDateTime');
        setState(() {
          _currentSessionStartTime = selectedDateTime;
        });
      }
    }
  }



  Future<void> x_showStartTimeDialog(BuildContext context) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(setTimeToDefaultSessionStartTime(_currentSessionStartTime)), // Default to current day at 19:30
      helpText: 'Select Session Start Time',
      initialEntryMode: TimePickerEntryMode.input,
    );

    if (pickedTime != null) {
      setState(() {
        _currentSessionStartTime = DateTime(
          _currentSessionStartTime.year,
          _currentSessionStartTime.month,
          _currentSessionStartTime.day,
          pickedTime.hour,
          pickedTime.minute,
        );
      });
    }
  }

  void _onPlayerSelected(int playerId) {
    setState(() {
      _selectedPlayerId = playerId;
      _sessionPanelListData = AppDatabase().fetchSessionPanelList(playerId: _selectedPlayerId);
    });
  }


  void _onStopAllSessions() {
    // Implement your logic to stop the session here
    debugPrint("Stop All Sessions button pressed!");
    // You'd likely update all running sessions' stop time and refresh the UI
  }

  void _onSessionSelected(int sessionId) {
    debugPrint("Session $sessionId selected!");
    // Implement your logic for when a session is selected
  }


  @override
  Widget build(BuildContext context) {
    final String formattedSessionStartTime =
        DateFormat('HH:mm:ss').format(_currentSessionStartTime);

    return Scaffold(
      appBar: AppBar(
        title: Text('Carolina Card Club',
                           // style: GoogleFonts.lato( // Replace with your chosen Google Font
                           //   fontSize: 48,
                           //   fontWeight: FontWeight.w700,
                           //   foreground: Paint()
                           //     ..style = PaintingStyle.stroke
                           //     ..strokeWidth = 2 // Adjust the stroke width as needed
                           //     ..color = Color(0xFF4B9CD3), // Adjust the stroke color as needed
                           // )
                    style: const TextStyle( // Replace with your chosen Google Font
                                   fontSize: 48,
                                   color: Color(0xFF4B9CD3), // Adjust the stroke color as needed
                                 )
               ),
        centerTitle: true,
        actions: <Widget>[
          // Settings Icon
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Handle settings icon press
              debugPrint("Settings icon pressed!");
            },
          ),
          // Clock
          Padding(
            padding: const EdgeInsets.only(right: 16.0), // Add some padding
            child: RealtimeClock(), // Your clock widget
          ),
        ],
      ),
      body: Row(
        children: [


          // Left Pane: Player List
          Expanded(
            flex: 1,
            child: FutureBuilder<List<PlayerSelectionItem>>( // Specify the data model type
              future: _playerListData,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No players found.'));
                } else {
                  final data = snapshot.data!; // Now 'data' is List<PlayerSelectionItem>
                  return ListView.builder(
                    itemCount: data.length,
                    itemBuilder: (context, index) {
                      final PlayerSelectionItem item = data[index]; // Directly access the data model object

                      // No need to extract playerId, playerName, playerBalance from a map
                      final int playerId = item.playerId;
                      final String playerName = item.name;
                      final double playerBalance = item.balance; // Balance is now directly accessible

                      // Determine background color based on balance
                      Color? cardColor = _selectedPlayerId == playerId ? Colors.blue.shade100 : null;
                      if (playerBalance < 0) { //  Directly use the balance property
                        cardColor = Colors.red.shade100;
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        color: cardColor,

                        child: MouseRegion(
                          onHover: (PointerHoverEvent event) {
                            if (event.synthesized == false && event.buttons == 0) {
                              if (HardwareKeyboard.instance.isShiftPressed) {
                                // Shift + hover detected
                              }
                            }
                          },
                          child: InkWell(
                            onTap: () {
                              if (HardwareKeyboard.instance.isShiftPressed) {
                                print("Shift + Left click!");
                              } else if (HardwareKeyboard.instance.isControlPressed) {
                                print("Ctrl/Cmd + Left click!");
                              } else if (HardwareKeyboard.instance.isAltPressed) {
                                print("Alt + Left click!");
                              } else {
                                print("Regular Left click!");
                              }
                              _onPlayerSelected(playerId); // Your original logic for player selection
                            },
                            onDoubleTap: () {
                              print("Double-tap!");
                            },
                            onLongPress: () {
                              print("Long press!");
                            },
                            onSecondaryTap: () {
                              print("Right click!");
                            },
                            child: ListTile(
                              title: Text(playerName),
                            ),
                          ),
                        )
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
            child: Column( // Use a Column to stack the header and the list
              children: [
                // *** This is your "title bar" for the right pane ***
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.grey[200], // A subtle background for the header
                    border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Session Start Time: $formattedSessionStartTime',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      ElevatedButton(
                        onPressed: _onStopAllSessions, // Call the stop all sessions method

                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,       // Background color of the button
                          foregroundColor: Colors.white,      // Text and icon color
                          elevation: 5,                       // Shadow elevation
                          shape: RoundedRectangleBorder(      // Custom shape
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(         // Style for the button's text
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15), // Padding
                        ),
                        child: const Text('Stop All Sessions'),
                      ),
                    ],
                  ),
                ),
                // End of the right pane's "title bar"

                // The rest of your session list
                Expanded( // Wrap your FutureBuilder in Expanded to fill the remaining space
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _sessionPanelListData,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      } else if (snapshot.data == null || snapshot.data!.isEmpty) {
                        if (_selectedPlayerId == null) {
                          return const Center(child: Text('Nothing to see here.'));
                        } else {
                          return const Center(child: Text('No sessions found for selected player.'));
                        }
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
                              child: MouseRegion(
                                onHover: (PointerHoverEvent event) {
                                  if (event.synthesized == false && event.buttons == 0) {
                                    if (HardwareKeyboard.instance.isShiftPressed) {
                                      // Shift + hover detected
                                      debugPrint("Shift + hover!");
                                    } else {
                                      // Hover detected
                                      // debugPrint("Hover!");
                                    }
                                  }
                                },
                                child: InkWell(
                                  onTap: () {
                                    if (HardwareKeyboard.instance.isShiftPressed) {
                                      // Shift + left click detected
                                      debugPrint("Shift + Left click!");
                                    } else if (HardwareKeyboard.instance.isControlPressed) {
                                      // Ctrl/Cmd + left click detected
                                      debugPrint("Ctrl/Cmd + Left click!");
                                    } else if (HardwareKeyboard.instance.isAltPressed) {
                                      // Alt + left click detected
                                      debugPrint("Alt + Left click!");
                                    } else {
                                      // Regular left click
                                      debugPrint("Regular Left click!");
                                    }
                                    _onSessionSelected(item['Session_Id']); // Your original logic for session selection
                                  },
                                  onSecondaryTap: () {
                                    // Right-click detected
                                    debugPrint("Right click!");
                                  },
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
                                        Text(
                                          'Amount: $formattedAmount',
                                          style: const TextStyle(fontSize: 18.0, color: Colors.green),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            );
                          },
                        );
                      }
                    },
                  ),
                ),
              ],
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
