import 'package:flutter/material.dart';

import 'bible_browser_screen.dart';
import 'plans_list_screen.dart';

/// App home: the plan tracker and the Bible reader, side by side.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [PlansListScreen(), BibleBrowserScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.checklist), label: 'Plans'),
          NavigationDestination(icon: Icon(Icons.menu_book), label: 'Read'),
        ],
      ),
    );
  }
}
