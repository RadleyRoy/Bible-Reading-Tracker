import 'package:bible_reading/main.dart';
import 'package:bible_reading/services/bible_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('create a plan, mark chapters read, and restart it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    // Preload the books the reader opens below; real asset IO cannot
    // complete inside the fake-async test zone.
    await tester.runAsync(() async {
      await BibleText.chapterVerses(0, 1); // Genesis
      await BibleText.chapterVerses(39, 1); // Matthew
    });
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

    // Continue reading from the plan: opens the first unread chapter.
    // Scroll all the way back to the top so the Today card is tappable.
    await tester.drag(find.byType(ListView).first, const Offset(0, 3000));
    await tester.pumpAndSettle();
    final continueButton = find.textContaining('Continue reading — Matthew 1');
    await tester.tap(continueButton);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('The book of the generation', findRichText: true),
      findsOneWidget,
    );
    await tester.tap(find.text('Mark read & continue'));
    await tester.pumpAndSettle();
    // Chapter 3 is already read, so after Matthew 1 comes Matthew 2.
    expect(find.text('Matthew 2'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Free reading from the Read tab.
    await tester.tap(find.text('Read'));
    await tester.pumpAndSettle();
    expect(find.text('Read the Bible'), findsOneWidget);
    await tester.tap(find.text('Genesis'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(Wrap), matching: find.text('2')).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Genesis 2'), findsOneWidget);
    expect(
      find.textContaining('Thus the heavens', findRichText: true),
      findsOneWidget,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    // The browser remembers where free reading left off.
    expect(find.text('Continue reading'), findsOneWidget);
    expect(find.text('Genesis 2'), findsOneWidget);

    // Settings tab: pick a Bible font.
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Bible text'), findsOneWidget);
    expect(
      find.textContaining('The LORD is my shepherd', findRichText: true),
      findsOneWidget,
    );
    await tester.tap(find.text('EB Garamond'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });
}
