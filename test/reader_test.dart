import 'package:bible_reading/models/plan.dart';
import 'package:bible_reading/screens/reader_screen.dart';
import 'package:bible_reading/services/bible_text.dart';
import 'package:bible_reading/services/plan_store.dart';
import 'package:bible_reading/services/reader_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<PlanStore> pumpReader(
    WidgetTester tester, {
    required int globalIndex,
    String? planId,
    PlanStore? store,
    ReaderSettings? settings,
  }) async {
    final planStore = store ?? PlanStore();
    if (store == null) await planStore.load();
    final readerSettings = settings ?? ReaderSettings();
    if (settings == null) await readerSettings.load();
    // Real asset IO cannot complete inside the fake-async test zone, so
    // pull the book into BibleText's cache first.
    final book = allChapters[globalIndex].bookIndex;
    await tester.runAsync(() => BibleText.chapterVerses(book, 1));
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: planStore),
          ChangeNotifierProvider.value(value: readerSettings),
        ],
        child: MaterialApp(
          home: ReaderScreen(globalIndex: globalIndex, planId: planId),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return planStore;
  }

  testWidgets('free reading renders Genesis 1 and navigates chapters', (
    tester,
  ) async {
    await pumpReader(tester, globalIndex: 0);

    expect(find.text('Genesis 1'), findsOneWidget);
    expect(
      find.textContaining('In the beginning God created', findRichText: true),
      findsOneWidget,
    );
    // No plan: shows position within the book instead of a mark button.
    expect(find.text('Chapter 1 of 50'), findsOneWidget);
    expect(find.text('Mark read & continue'), findsNothing);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.text('Genesis 2'), findsOneWidget);

    // The free-reading position is remembered.
    expect(await ReadingPosition.load(), 1);
  });

  testWidgets('plan reading marks the chapter and advances to the next', (
    tester,
  ) async {
    final store = PlanStore();
    await store.load();
    final today = DateTime.now();
    final plan = Plan(
      id: 'p1',
      name: 'NT plan',
      startBook: 39,
      endBook: 65,
      startDate: today,
      endDate: today.add(const Duration(days: 89)),
    );
    await store.addPlan(plan);
    final matthew1 = bookStartIndex[39];

    await pumpReader(tester, globalIndex: matthew1, planId: 'p1', store: store);
    expect(find.text('Matthew 1'), findsOneWidget);

    await tester.tap(find.text('Mark read & continue'));
    await tester.pumpAndSettle();

    expect(plan.isRead(matthew1), isTrue);
    expect(find.text('Matthew 2'), findsOneWidget);
    expect(find.text('Mark read & continue'), findsOneWidget);
  });

  testWidgets('verse text uses the configured font, the chrome does not', (
    tester,
  ) async {
    final settings = ReaderSettings();
    await settings.load();
    await settings.setFontFamily('Lora');
    await settings.setFontSize(22);

    await pumpReader(tester, globalIndex: 0, settings: settings);

    final verse = tester.widget<Text>(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            (w.textSpan?.toPlainText().contains('In the beginning') ?? false),
      ),
    );
    expect(verse.style?.fontFamily, 'Lora');
    expect(verse.style?.fontSize, 22);

    // The app bar title keeps the theme font.
    final title = tester.widget<Text>(find.text('Genesis 1'));
    expect(title.style?.fontFamily, isNot('Lora'));
  });

  testWidgets('an already-read chapter shows a read indicator', (tester) async {
    final store = PlanStore();
    await store.load();
    final today = DateTime.now();
    final plan = Plan(
      id: 'p1',
      name: 'NT plan',
      startBook: 39,
      endBook: 65,
      startDate: today,
      endDate: today.add(const Duration(days: 89)),
    );
    plan.readChapters.add(bookStartIndex[39]);
    await store.addPlan(plan);

    await pumpReader(
      tester,
      globalIndex: bookStartIndex[39],
      planId: 'p1',
      store: store,
    );
    expect(find.text('Read'), findsOneWidget);
    expect(find.text('Mark read & continue'), findsNothing);
  });
}
