import 'package:bible_reading/screens/search_screen.dart';
import 'package:bible_reading/services/bible_text.dart';
import 'package:bible_reading/services/plan_store.dart';
import 'package:bible_reading/services/reader_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpSearch(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = PlanStore();
    await store.load();
    final settings = ReaderSettings();
    await settings.load();
    // Search scans every book; the assets cannot load inside the
    // fake-async zone, so cache them all up front.
    await tester.runAsync(BibleText.ensureAllLoaded);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: store),
          ChangeNotifierProvider.value(value: settings),
        ],
        child: const MaterialApp(home: SearchScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('searches and opens the result in the reader', (tester) async {
    await pumpSearch(tester);

    await tester.enterText(
      find.byType(TextField),
      'For God so loved the world',
    );
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    expect(find.text('1 verse found'), findsOneWidget);
    expect(find.text('John 3:16'), findsOneWidget);

    await tester.tap(find.text('John 3:16'));
    await tester.pumpAndSettle();
    expect(find.text('John 3'), findsOneWidget); // reader app bar
  });

  testWidgets('reports when nothing matches', (tester) async {
    await pumpSearch(tester);
    await tester.enterText(find.byType(TextField), 'zzzznotaword');
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    expect(find.textContaining('No verses match'), findsOneWidget);
  });
}
