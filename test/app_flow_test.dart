import 'package:bible_reading/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('create a plan, mark chapters read, and restart it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const BibleReadingApp());
    await tester.pumpAndSettle();

    // Create a New Testament plan.
    await tester.tap(find.text('New plan'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'NT in 90 days');
    await tester.tap(find.text('Whole Bible'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New Testament').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Matthew – Revelation'), findsOneWidget);
    await tester.tap(find.text('Create plan'));
    await tester.pumpAndSettle();

    // The plan card shows up on the home screen.
    expect(find.text('NT in 90 days'), findsOneWidget);
    expect(find.textContaining('0 of 260 chapters'), findsOneWidget);

    // Open the plan and read today's first chapter.
    await tester.tap(find.text('NT in 90 days'));
    await tester.pumpAndSettle();
    expect(find.text("Today's reading"), findsOneWidget);
    expect(find.text('Matthew 1'), findsOneWidget);
    await tester.tap(find.text('Matthew 1'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 260 chapters'), findsOneWidget);

    // Unmark it again.
    await tester.tap(find.text('Matthew 1'));
    await tester.pumpAndSettle();
    expect(find.text('0 of 260 chapters'), findsOneWidget);

    // Mark it once more and restart the plan from the menu.
    await tester.tap(find.text('Matthew 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restart'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Restart'));
    await tester.pumpAndSettle();
    expect(find.text('0 of 260 chapters'), findsOneWidget);

    // Marking a chapter from the book grid works too.
    await tester.scrollUntilVisible(find.text('Matthew'), 300);
    await tester.tap(find.text('Matthew'));
    await tester.pumpAndSettle();
    final chapterThree = find.descendant(
      of: find.byType(Wrap),
      matching: find.text('3'),
    );
    await tester.scrollUntilVisible(chapterThree, 100);
    await tester.tap(chapterThree);
    await tester.pumpAndSettle();
    // The header is scrolled out of view, so check the book subtitle.
    expect(find.text('1 / 28 read'), findsOneWidget);
  });
}
