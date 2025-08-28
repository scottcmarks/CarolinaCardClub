import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/api_provider.dart';
import 'providers/time_provider.dart';
import 'providers/app_settings_provider.dart';
import 'widgets/main_split_view_page.dart';

void main() {
  runApp(const CarolinaCardClubApp());
}

class CarolinaCardClubApp extends StatelessWidget {
  const CarolinaCardClubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => TimeProvider()),
        ChangeNotifierProvider(create: (context) => AppSettingsProvider()),
        ChangeNotifierProvider(create: (context) => ApiProvider()),
      ],
      child: MaterialApp(
        title: 'Carolina Card Club',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const MainSplitViewPage(),
      ),
    );
  }
}
