import 'dart:async';

import 'package:flutter/material.dart';

import '../data/kjv_data.dart';
import '../services/bible_search.dart';
import 'reader_screen.dart';

/// Which part of the Bible a search covers.
enum _Scope { all, oldTestament, newTestament, custom }

/// Full-text search over the bundled KJV — works completely offline.
/// Results appear as you type, and can be narrowed to a set of books.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _maxShown = 300;
  static const _debounce = Duration(milliseconds: 300);

  final TextEditingController _controller = TextEditingController();
  Timer? _timer;
  int _requestId = 0;

  _Scope _scope = _Scope.all;
  Set<int> _customBooks = {};
  List<SearchHit>? _hits;
  String _query = '';
  bool _searching = false;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Set<int>? get _bookFilter => switch (_scope) {
    _Scope.all => null,
    _Scope.oldTestament => {for (var b = 0; b < oldTestamentBookCount; b++) b},
    _Scope.newTestament => {
      for (var b = oldTestamentBookCount; b < kjvBooks.length; b++) b,
    },
    _Scope.custom => _customBooks,
  };

  void _onChanged(String text) {
    _timer?.cancel();
    if (text.trim().length < 2) {
      // Cleared or too short: back to the idle state.
      setState(() {
        _hits = null;
        _query = '';
        _searching = false;
      });
      return;
    }
    _timer = Timer(_debounce, () => _run(text));
  }

  Future<void> _run(String query) async {
    final q = query.trim();
    if (q.length < 2) return;
    _timer?.cancel();
    final request = ++_requestId;
    setState(() {
      _searching = _hits == null;
      _query = q;
    });
    final hits = await searchBible(q, books: _bookFilter);
    if (!mounted || request != _requestId) return;
    setState(() {
      _hits = hits;
      _searching = false;
    });
  }

  void _setScope(_Scope scope) {
    setState(() => _scope = scope);
    if (_query.isNotEmpty) _run(_controller.text);
  }

  Future<void> _pickBooks() async {
    final picked = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BookPicker(
        initial: _scope == _Scope.custom
            ? _customBooks
            : (_bookFilter ?? {for (var b = 0; b < kjvBooks.length; b++) b}),
      ),
    );
    if (picked == null) return;
    _customBooks = picked;
    _setScope(_Scope.custom);
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
          onChanged: _onChanged,
          onSubmitted: _run,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _scope == _Scope.all,
                  onSelected: (_) => _setScope(_Scope.all),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Old Testament'),
                  selected: _scope == _Scope.oldTestament,
                  onSelected: (_) => _setScope(_Scope.oldTestament),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('New Testament'),
                  selected: _scope == _Scope.newTestament,
                  onSelected: (_) => _setScope(_Scope.newTestament),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: Text(
                    _scope == _Scope.custom
                        ? '${_customBooks.length} '
                              '${_customBooks.length == 1 ? 'book' : 'books'}'
                        : 'Select books…',
                  ),
                  selected: _scope == _Scope.custom,
                  onSelected: (_) => _pickBooks(),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _searching
          ? const Center(child: CircularProgressIndicator())
          : hits == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Search all 31,102 verses of the KJV — results appear '
                  'as you type. Try "shepherd".',
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

/// Bottom sheet with a checkbox per book plus quick actions.
class _BookPicker extends StatefulWidget {
  final Set<int> initial;

  const _BookPicker({required this.initial});

  @override
  State<_BookPicker> createState() => _BookPickerState();
}

class _BookPickerState extends State<_BookPicker> {
  late final Set<int> _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Search in…',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(
                      () => _selected
                        ..clear()
                        ..addAll([for (var b = 0; b < kjvBooks.length; b++) b]),
                    ),
                    child: const Text('All'),
                  ),
                  TextButton(
                    onPressed: () => setState(_selected.clear),
                    child: const Text('None'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (var b = 0; b < kjvBooks.length; b++) ...[
                    if (b == 0 || b == oldTestamentBookCount)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          b == 0 ? 'Old Testament' : 'New Testament',
                          style: theme.textTheme.titleSmall!.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    CheckboxListTile(
                      dense: true,
                      title: Text(kjvBooks[b].name),
                      value: _selected.contains(b),
                      onChanged: (v) => setState(() {
                        if (v ?? false) {
                          _selected.add(b);
                        } else {
                          _selected.remove(b);
                        }
                      }),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.pop(context, _selected),
                  child: Text(
                    'Search ${_selected.length} '
                    '${_selected.length == 1 ? 'book' : 'books'}',
                  ),
                ),
              ),
            ),
          ],
        ),
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
