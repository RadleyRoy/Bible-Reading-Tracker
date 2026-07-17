import 'package:bible_reading/services/bible_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('finds John 3:16 by phrase', () async {
    final hits = await searchBible('For God so loved the world');
    expect(hits, hasLength(1));
    expect(hits.single.reference, 'John 3:16');
    expect(hits.single.verse, 16);
  });

  test('search is case-insensitive', () async {
    final upper = await searchBible('SHEPHERD');
    final lower = await searchBible('shepherd');
    expect(upper.length, lower.length);
    expect(upper, isNotEmpty);
  });

  test('queries shorter than two characters return nothing', () async {
    expect(await searchBible('a'), isEmpty);
    expect(await searchBible('  '), isEmpty);
  });

  test('multi-hit query returns verses in canonical order', () async {
    final hits = await searchBible('In the beginning');
    expect(hits.first.reference, 'Genesis 1:1');
    final indices = hits.map((h) => h.chapter.globalIndex).toList();
    final sorted = [...indices]..sort();
    expect(indices, sorted);
  });
}
