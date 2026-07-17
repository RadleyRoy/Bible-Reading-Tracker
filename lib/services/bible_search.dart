import '../data/kjv_data.dart';
import '../models/plan.dart';
import 'bible_text.dart';

/// One verse matching a search query.
class SearchHit {
  final ChapterRef chapter;

  /// 1-based verse number within the chapter.
  final int verse;
  final String text;

  const SearchHit(this.chapter, this.verse, this.text);

  String get reference => '${chapter.reference}:$verse';
}

/// Case-insensitive substring search across the bundled verses.
/// Queries shorter than 2 characters return nothing. When [books] is
/// given, only those book indices are searched (an empty set matches
/// nothing).
Future<List<SearchHit>> searchBible(String query, {Set<int>? books}) async {
  final q = query.trim().toLowerCase();
  if (q.length < 2) return const [];

  await BibleText.ensureAllLoaded();
  final hits = <SearchHit>[];
  for (var b = 0; b < kjvBooks.length; b++) {
    if (books != null && !books.contains(b)) continue;
    final chapters = await BibleText.book(b);
    for (var c = 0; c < chapters.length; c++) {
      final verses = chapters[c];
      for (var v = 0; v < verses.length; v++) {
        if (verses[v].toLowerCase().contains(q)) {
          hits.add(
            SearchHit(allChapters[bookStartIndex[b] + c], v + 1, verses[v]),
          );
        }
      }
    }
  }
  return hits;
}
