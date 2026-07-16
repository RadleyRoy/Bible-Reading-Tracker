import 'package:bible_reading/models/plan.dart';
import 'package:bible_reading/screens/reader_screen.dart';
import 'package:bible_reading/services/bible_text.dart';
import 'package:bible_reading/services/plan_store.dart';
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
  }) async {
    final planStore = store ?? PlanStore();
    if (store == null) await planStore.load();
    // Real asset IO cannot complete inside the fake-async test zone, so
    // pull the book into BibleText's cache first.
    final book = allChapters[globalIndex].bookIndex;
    await tester.runAsync(() => BibleText.chapterVerses(book, 1));
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: planStore,
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
