import 'package:flutter/material.dart';

import '../services/bible_search.dart';
import 'reader_screen.dart';

/// Full-text search over the bundled KJV — works completely offline.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _maxShown = 300;

  final TextEditingController _controller = TextEditingController();
  List<SearchHit>? _hits;
  String _query = '';
  bool _searching = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run(String query) async {
    final q = query.trim();
    if (q.length < 2) return;
    setState(() {
      _searching = true;
      _query = q;
    });
    final hits = await searchBible(q);
    if (!mounted) return;
    setState(() {
      _hits = hits;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hits = _hits;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search the Bible…',
            border: InputBorder.none,
          ),
          onSubmitted: _run,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () => _run(_controller.text),
          ),
        ],
      ),
      body: _searching
          ? const Center(child: CircularProgressIndicator())
          : hits == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Search all 31,102 verses of the KJV — '
                  'try "shepherd" or "faith, hope".',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            )
          : hits.isEmpty
          ? Center(child: Text('No verses match "$_query".'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    hits.length == 1
                        ? '1 verse found'
                        : '${hits.length} verses found'
                              '${hits.length > _maxShown ? ' · showing first $_maxShown' : ''}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: hits.length > _maxShown
                        ? _maxShown
                        : hits.length,
                    itemBuilder: (context, i) =>
                        _ResultTile(hit: hits[i], query: _query),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final SearchHit hit;
  final String query;

  const _ResultTile({required this.hit, required this.query});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: ListTile(
        title: Text(hit.reference, style: theme.textTheme.titleSmall),
        subtitle: Text.rich(
          TextSpan(children: _highlighted(hit.text, query, theme)),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReaderScreen(
              globalIndex: hit.chapter.globalIndex,
              highlightVerse: hit.verse,
            ),
          ),
        ),
      ),
    );
  }

  List<TextSpan> _highlighted(String text, String query, ThemeData theme) {
    final spans = <TextSpan>[];
    final lower = text.toLowerCase();
    final q = query.toLowerCase();
    var start = 0;
    while (true) {
      final at = lower.indexOf(q, start);
      if (at < 0) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (at > start) spans.add(TextSpan(text: text.substring(start, at)));
      spans.add(
        TextSpan(
          text: text.substring(at, at + q.length),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      );
      start = at + q.length;
    }
    return spans;
  }
}
