import 'package:bible_reading/screens/settings_screen.dart';
import 'package:bible_reading/services/reader_settings.dart';
import 'package:bible_reading/widgets/verse_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const sample = 'The LORD is my shepherd; I shall not want.';

  Text sampleText(WidgetTester tester) => tester.widget<Text>(
    find.descendant(of: find.byType(VerseText), matching: find.byType(Text)),
  );

  Future<ReaderSettings> pumpSettings(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = ReaderSettings();
    await settings.load();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return settings;
  }

  testWidgets('shows the sample verse and all font options', (tester) async {
    await pumpSettings(tester);
    expect(find.textContaining(sample, findRichText: true), findsOneWidget);
    for (final font in ReaderSettings.fonts) {
      expect(find.text(font.label), findsOneWidget);
    }
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('selecting a font updates the sample and persists', (
    tester,
  ) async {
    final settings = await pumpSettings(tester);
    expect(sampleText(tester).style?.fontFamily, isNull);

    await tester.tap(find.text('Merriweather'));
    await tester.pumpAndSettle();

    expect(settings.fontFamily, 'Merriweather');
    expect(sampleText(tester).style?.fontFamily, 'Merriweather');

    final reloaded = ReaderSettings();
    await reloaded.load();
    expect(reloaded.fontFamily, 'Merriweather');
  });

  testWidgets('the size slider updates the sample text size', (tester) async {
    final settings = await pumpSettings(tester);
    expect(sampleText(tester).style?.fontSize, ReaderSettings.defaultSize);

    // Scroll the slider into view, then drag the thumb fully right.
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Slider), const Offset(400, 0));
    await tester.pumpAndSettle();

    expect(settings.fontSize, ReaderSettings.maxSize);
    expect(sampleText(tester).style?.fontSize, ReaderSettings.maxSize);
  });

  testWidgets('reset returns the sample to defaults', (tester) async {
    final settings = await pumpSettings(tester);
    await tester.tap(find.text('Lora'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Slider), const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(settings.fontFamily, 'Lora');
    expect(settings.fontSize, ReaderSettings.maxSize);

    await tester.tap(find.text('Reset to defaults'));
    await tester.pumpAndSettle();

    expect(settings.fontFamily, isNull);
    expect(settings.fontSize, ReaderSettings.defaultSize);
    expect(sampleText(tester).style?.fontSize, ReaderSettings.defaultSize);
  });
}
