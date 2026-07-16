import 'package:bible_reading/data/kjv_data.dart';
import 'package:bible_reading/services/bible_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every book asset loads and has its last chapter', () async {
    for (var b = 0; b < kjvBooks.length; b++) {
      final lastChapter = await BibleText.chapterVerses(
        b,
        kjvBooks[b].chapterCount,
      );
      expect(lastChapter, isNotEmpty, reason: kjvBooks[b].name);
    }
  });

  test('Genesis 1 is correct', () async {
    final verses = await BibleText.chapterVerses(0, 1);
    expect(verses.length, 31);
    expect(verses.first, startsWith('In the beginning God created'));
  });

  test('John 3 has 36 verses including 3:16', () async {
    final verses = await BibleText.chapterVerses(42, 3);
    expect(verses.length, 36);
    expect(verses[15], contains('For God so loved the world'));
  });

  test('Psalm 117 has 2 verses', () async {
    final verses = await BibleText.chapterVerses(18, 117);
    expect(verses.length, 2);
  });

  test('Revelation 22 (the last chapter) has 21 verses', () async {
    final verses = await BibleText.chapterVerses(65, 22);
    expect(verses.length, 21);
  });
}
