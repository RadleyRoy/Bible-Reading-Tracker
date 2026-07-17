import 'package:bible_reading/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app starts and shows the empty state', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const BibleReadingApp());
    await tester.pumpAndSettle();

    expect(find.text('Bible Reading Plans'), findsOneWidget);
    expect(find.text('No reading plans yet'), findsOneWidget);
    expect(find.text('New plan'), findsOneWidget);
    expect(find.text('created by radley'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
