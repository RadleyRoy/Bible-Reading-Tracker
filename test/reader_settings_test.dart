import 'package:bible_reading/services/reader_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to the system font at 17pt', () async {
    final settings = ReaderSettings();
    await settings.load();
    expect(settings.fontFamily, isNull);
    expect(settings.fontSize, ReaderSettings.defaultSize);
  });

  test('font family and size survive a reload', () async {
    final settings = ReaderSettings();
    await settings.load();
    await settings.setFontFamily('Lora');
    await settings.setFontSize(22);

    final reloaded = ReaderSettings();
    await reloaded.load();
    expect(reloaded.fontFamily, 'Lora');
    expect(reloaded.fontSize, 22);
  });

  test('reset returns to defaults and persists', () async {
    final settings = ReaderSettings();
    await settings.load();
    await settings.setFontFamily('Merriweather');
    await settings.setFontSize(24);
    await settings.reset();

    expect(settings.fontFamily, isNull);
    expect(settings.fontSize, ReaderSettings.defaultSize);

    final reloaded = ReaderSettings();
    await reloaded.load();
    expect(reloaded.fontFamily, isNull);
    expect(reloaded.fontSize, ReaderSettings.defaultSize);
  });

  test('offers the default plus the four bundled families', () {
    expect(ReaderSettings.fonts, hasLength(5));
    expect(ReaderSettings.fonts.first.family, isNull);
    expect(ReaderSettings.fonts.map((f) => f.family).skip(1), [
      'Lora',
      'Merriweather',
      'EB Garamond',
      'Open Sans',
    ]);
  });
}
