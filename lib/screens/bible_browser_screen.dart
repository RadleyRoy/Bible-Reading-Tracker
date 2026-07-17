import 'package:flutter/material.dart';

import '../data/kjv_data.dart';
import '../models/plan.dart';
import '../services/bible_text.dart';
import 'reader_screen.dart';
import 'search_screen.dart';

/// Free reading: pick any book and chapter of the KJV, with a shortcut to
/// continue from the last chapter read outside a plan.
class BibleBrowserScreen extends StatefulWidget {
  const BibleBrowserScreen({super.key});

  @override
  State<BibleBrowserScreen> createState() => _BibleBrowserScreenState();
}

class _BibleBrowserScreenState extends State<BibleBrowserScreen> {
  int? _lastPosition;

  @override
  void initState() {
    super.initState();
    _refreshPosition();
  }

  Future<void> _refreshPosition() async {
    final position = await ReadingPosition.load();
    if (mounted) setState(() => _lastPosition = position);
  }

  Future<void> _open(int globalIndex) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReaderScreen(globalIndex: globalIndex)),
    );
    _refreshPosition();
  }

  @override
  Widget build(BuildContext context) {
    final last = _lastPosition;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Read the Bible'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search the Bible',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        children: [
          if (last != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.bookmark),
                title: const Text('Continue reading'),
                subtitle: Text(allChapters[last].reference),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(last),
              ),
            ),
          for (var b = 0; b < kjvBooks.length; b++) _bookTile(b),
        ],
      ),
    );
  }

  Widget _bookTile(int bookIndex) {
    final book = kjvBooks[bookIndex];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ExpansionTile(
        shape: const Border(),
        title: Text(book.name),
        subtitle: Text(
          '${book.chapterCount} ${book.chapterCount == 1 ? 'chapter' : 'chapters'}',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var c = 0; c < book.chapterCount; c++)
                  _chapterButton(bookIndex, c),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chapterButton(int bookIndex, int chapterOffset) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: () => _open(bookStartIndex[bookIndex] + chapterOffset),
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Text(
              '${chapterOffset + 1}',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        ),
      ),
    );
  }
}
