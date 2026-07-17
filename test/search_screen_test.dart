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

  /// Lets the debounce fire and the search complete.
  Future<void> settleSearch(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  testWidgets('results appear while typing, without submitting', (
    tester,
  ) async {
    await pumpSearch(tester);

    await tester.enterText(
      find.byType(TextField),
      'For God so loved the world',
    );
    await settleSearch(tester);

    expect(find.text('1 verse found'), findsOneWidget);
    expect(find.text('John 3:16'), findsOneWidget);

    // Typing more re-runs the search.
    await tester.enterText(
      find.byType(TextField),
      'For God so loved the world, that he gave',
    );
    await settleSearch(tester);
    expect(find.text('1 verse found'), findsOneWidget);

    // Clearing returns to the idle state.
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(find.textContaining('results appear'), findsOneWidget);
  });

  testWidgets('opens a result in the reader', (tester) async {
    await pumpSearch(tester);
    await tester.enterText(
      find.byType(TextField),
      'For God so loved the world',
    );
    await settleSearch(tester);

    await tester.tap(find.text('John 3:16'));
    await tester.pumpAndSettle();
    expect(find.text('John 3'), findsOneWidget); // reader app bar
  });

  testWidgets('testament chips narrow the results', (tester) async {
    await pumpSearch(tester);
    await tester.enterText(find.byType(TextField), 'shepherd');
    await settleSearch(tester);

    final allCount = int.parse(
      RegExp(r'(\d+) verses found')
          .firstMatch(
            (tester.widget<Text>(find.textContaining('verses found')).data)!,
          )!
          .group(1)!,
    );

    await tester.tap(find.text('New Testament'));
    await settleSearch(tester);
    final ntCount = int.parse(
      RegExp(r'(\d+) verses found')
          .firstMatch(
            (tester.widget<Text>(find.textContaining('verses found')).data)!,
          )!
          .group(1)!,
    );
    expect(ntCount, lessThan(allCount));
    // The Old Testament shepherd verses are gone.
    expect(find.text('Genesis 46:32'), findsNothing);
  });

  testWidgets('the book picker restricts search to chosen books', (
    tester,
  ) async {
    await pumpSearch(tester);
    await tester.enterText(find.byType(TextField), 'shepherd');
    await settleSearch(tester);

    await tester.tap(find.text('Select books…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('None'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Psalms'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Psalms'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Search 1 book'));
    await settleSearch(tester);

    expect(find.text('1 book'), findsOneWidget); // the custom chip label
    expect(find.textContaining('Psalms 23:1'), findsOneWidget);
    expect(find.text('Genesis 46:32'), findsNothing);
  });

  testWidgets('reports when nothing matches', (tester) async {
    await pumpSearch(tester);
    await tester.enterText(find.byType(TextField), 'zzzznotaword');
    await settleSearch(tester);
    expect(find.textContaining('No verses match'), findsOneWidget);
  });
}
