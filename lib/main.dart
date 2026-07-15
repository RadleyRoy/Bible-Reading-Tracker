import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/plans_list_screen.dart';
import 'services/plan_store.dart';

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
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6D4C41)),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6D4C41),
            brightness: Brightness.dark,
          ),
        ),
        home: const PlansListScreen(),
      ),
    );
  }
}
