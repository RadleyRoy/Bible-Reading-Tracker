import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'services/plan_store.dart';
import 'theme.dart';

void main() {
  runApp(const BibleReadingApp());
}

class BibleReadingApp extends StatelessWidget {
  const BibleReadingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PlanStore()..load(),
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
