import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/kjv_data.dart';
import '../models/plan.dart';
import '../services/bible_text.dart';
import '../services/plan_store.dart';
import '../services/reader_settings.dart';
import '../widgets/verse_text.dart';

/// Reads a chapter of the bundled KJV text.
///
/// Navigates by global chapter index so previous/next crosses book
/// boundaries. With a [planId], shows a "Mark read & continue" action that
/// checks the chapter off in that plan and advances to its next unread
/// chapter (and, when the auto-mark setting is on, reaching the end of the
/// chapter checks it off by itself). Without one (free reading), the
/// position is remembered so the Read tab can offer to continue where you
/// left off. [highlightVerse] tints one verse and jumps near it — used by
/// search results.
class ReaderScreen extends StatefulWidget {
  final int globalIndex;
  final String? planId;
  final int? highlightVerse;

  const ReaderScreen({
    super.key,
    required this.globalIndex,
    this.planId,
    this.highlightVerse,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final ScrollController _scroll = ScrollController();
  late int _index;
  int? _highlight;
  int? _pendingJump;
  bool _autoMarkDone = false;

  @override
  void initState() {
    super.initState();
    _index = widget.globalIndex;
    _highlight = widget.highlightVerse;
    _pendingJump = widget.highlightVerse;
    _savePosition();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _go(int index) {
    setState(() {
      _index = index;
      _highlight = null;
      _pendingJump = null;
      _autoMarkDone = false;
    });
    _savePosition();
  }

  void _savePosition() {
    if (widget.planId == null) ReadingPosition.save(_index);
  }

  Plan? get _plan => widget.planId == null
      ? null
      : context.read<PlanStore>().planById(widget.planId!);

  bool _inPlan(Plan plan) {
    final start = bookStartIndex[plan.startBook];
    final end =
        bookStartIndex[plan.endBook] + kjvBooks[plan.endBook].chapterCount;
    return _index >= start && _index < end;
  }

  /// Marks the current chapter read in [plan], with completion feedback.
  Future<void> _markCurrent(Plan plan, {required bool advance}) async {
    final store = context.read<PlanStore>();
    final messenger = ScaffoldMessenger.of(context);
    final reference = allChapters[_index].reference;
    final wasInToday = plan.assignedChapters.contains(_index);

    await store.markRead(plan, _index);

    if (plan.isComplete) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Plan complete — well done!')),
      );
      return;
    }
    final todayDone =
        wasInToday && plan.assignedChapters.every(plan.readChapters.contains);
    if (todayDone) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Today's reading complete!")),
      );
    } else if (!advance) {
      messenger.showSnackBar(
        SnackBar(content: Text('$reference marked as read')),
      );
    }
    if (advance) {
      final next = plan.nextUnreadChapter;
      if (next != null) _go(next);
    }
  }

  /// Auto-marks the chapter when its end is reached, if enabled.
  void _tryAutoMark() {
    if (_autoMarkDone || widget.planId == null) return;
    if (!context.read<ReaderSettings>().autoMark) return;
    final plan = _plan;
    if (plan == null || !_inPlan(plan) || plan.isRead(_index)) return;
    _autoMarkDone = true;
    _markCurrent(plan, advance: false);
  }

  void _afterBuild(int verseCount) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      if (_pendingJump != null && verseCount > 0 && max > 0) {
        final fraction = (_pendingJump! - 1) / verseCount;
        _scroll.jumpTo((max * fraction).clamp(0.0, max));
      }
      _pendingJump = null;
      // A chapter that fits on one screen has no scrolling to finish it.
      if (max == 0) _tryAutoMark();
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<PlanStore>();
    final settings = context.watch<ReaderSettings>();
    final plan = widget.planId == null ? null : store.planById(widget.planId!);
    final chapter = allChapters[_index];

    return Scaffold(
      appBar: AppBar(title: Text(chapter.reference)),
      body: FutureBuilder<List<String>>(
        future: BibleText.chapterVerses(chapter.bookIndex, chapter.chapter),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Could not load text: ${snapshot.error}'),
            );
          }
          final verses = snapshot.data;
          if (verses == null) {
            return const Center(child: CircularProgressIndicator());
          }
          _afterBuild(verses.length);
          return NotificationListener<ScrollUpdateNotification>(
            onNotification: (n) {
              if (n.metrics.pixels >= n.metrics.maxScrollExtent - 32) {
                _tryAutoMark();
              }
              return false;
            },
            child: SelectionArea(
              child: ListView.builder(
                key: PageStorageKey('chapter-$_index'),
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                itemCount: verses.length,
                itemBuilder: (context, i) {
                  final verse = VerseText(
                    number: i + 1,
                    text: verses[i],
                    fontFamily: settings.fontFamily,
                    fontSize: settings.fontSize,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: i + 1 == _highlight
                        ? Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.all(6),
                            child: verse,
                          )
                        : verse,
                  );
                },
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          children: [
            IconButton(
              onPressed: _index > 0 ? () => _go(_index - 1) : null,
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Previous chapter',
            ),
            Expanded(child: Center(child: _centerAction(plan))),
            IconButton(
              onPressed: _index < allChapters.length - 1
                  ? () => _go(_index + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Next chapter',
            ),
          ],
        ),
      ),
    );
  }

  Widget _centerAction(Plan? plan) {
    final chapter = allChapters[_index];
    if (plan == null) {
      return Text(
        'Chapter ${chapter.chapter} of '
        '${kjvBooks[chapter.bookIndex].chapterCount}',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    if (!_inPlan(plan)) {
      return Text(
        'Not part of this plan',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    if (plan.isRead(_index)) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 6),
          const Text('Read'),
        ],
      );
    }
    return FilledButton.icon(
      onPressed: () => _markCurrent(plan, advance: true),
      icon: const Icon(Icons.check),
      label: const Text('Mark read & continue'),
    );
  }
}
