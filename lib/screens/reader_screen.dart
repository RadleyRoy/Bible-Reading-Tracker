import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/kjv_data.dart';
import '../models/plan.dart';
import '../services/bible_text.dart';
import '../services/plan_store.dart';

/// Reads a chapter of the bundled KJV text.
///
/// Navigates by global chapter index so previous/next crosses book
/// boundaries. With a [planId], shows a "Mark read & continue" action that
/// checks the chapter off in that plan and advances to its next unread
/// chapter; without one (free reading), the position is remembered so the
/// Read tab can offer to continue where you left off.
class ReaderScreen extends StatefulWidget {
  final int globalIndex;
  final String? planId;

  const ReaderScreen({super.key, required this.globalIndex, this.planId});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.globalIndex;
    _savePosition();
  }

  void _go(int index) {
    setState(() => _index = index);
    _savePosition();
  }

  void _savePosition() {
    if (widget.planId == null) ReadingPosition.save(_index);
  }

  Future<void> _markAndContinue(Plan plan) async {
    final store = context.read<PlanStore>();
    final messenger = ScaffoldMessenger.of(context);
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
    }
    final next = plan.nextUnreadChapter;
    if (next != null) _go(next);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<PlanStore>();
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
          return SelectionArea(
            child: ListView.builder(
              key: PageStorageKey('chapter-$_index'),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              itemCount: verses.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${i + 1}  ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      TextSpan(text: verses[i]),
                    ],
                  ),
                  style: const TextStyle(fontSize: 17, height: 1.6),
                ),
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

    final start = bookStartIndex[plan.startBook];
    final end =
        bookStartIndex[plan.endBook] + kjvBooks[plan.endBook].chapterCount;
    if (_index < start || _index >= end) {
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
      onPressed: () => _markAndContinue(plan),
      icon: const Icon(Icons.check),
      label: const Text('Mark read & continue'),
    );
  }
}
