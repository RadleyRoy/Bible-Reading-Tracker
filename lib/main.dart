import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'services/plan_store.dart';
import 'services/reader_settings.dart';
import 'services/reminder_service.dart';
import 'theme.dart';

void main() {
  runApp(const BibleReadingApp());
}

class BibleReadingApp extends StatelessWidget {
  const BibleReadingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlanStore()..load()),
        ChangeNotifierProvider(create: (_) => ReaderSettings()..load()),
        ChangeNotifierProvider(create: (_) => ReminderService()..load()),
      ],
      child: MaterialApp(
        title: 'Bible Reading',
        debugShowCheckedModeBanner: false,
        theme: lightTheme(),
        darkTheme: darkTheme(),
        home: const HomeScreen(),
      ),
    );
  }
}
