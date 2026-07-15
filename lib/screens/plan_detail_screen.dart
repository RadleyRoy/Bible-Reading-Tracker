import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/kjv_data.dart';
import '../models/plan.dart';
import '../services/plan_store.dart';
import '../services/scheduler.dart';
import '../utils.dart';
import 'plans_list_screen.dart';

class PlanDetailScreen extends StatefulWidget {
  final String planId;

  const PlanDetailScreen({super.key, required this.planId});

  @override
  State<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends State<PlanDetailScreen> {
  /// Today's portion, pinned when the screen opens so checked chapters
  /// stay visible instead of being rebalanced away mid-session.
  List<int> _todayIndices = [];

  @override
  void initState() {
    super.initState();
    _refreshToday();
  }

  void _refreshToday() {
    final plan = context.read<PlanStore>().planById(widget.planId);
    if (plan == null) return;
    final stats = computeStats(plan, DateTime.now());
    setState(() {
      _todayIndices =
          stats.today?.chapters.map((c) => c.globalIndex).toList() ?? [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<PlanStore>();
    final plan = store.planById(widget.planId);
    if (plan == null) {
      // Plan was deleted; nothing to show.
      return const Scaffold(body: SizedBox.shrink());
    }

    final stats = computeStats(plan, DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text(plan.name),
        actions: [
          PlanMenuButton(
            plan: plan,
            onChanged: _refreshToday,
            onDeleted: () => Navigator.pop(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _ProgressHeader(plan: plan, stats: stats),
          const SizedBox(height: 12),
          if (stats.isComplete)
            const _CompletedCard()
          else
            _TodayCard(
              plan: plan,
              todayIndices: _todayIndices,
              isOverdue: stats.isOverdue,
            ),
          if (stats.upcoming.isNotEmpty) ...[
            const SizedBox(height: 12),
            _UpcomingCard(upcoming: stats.upcoming),
          ],
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('All chapters',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          const SizedBox(height: 4),
          for (var b = plan.startBook; b <= plan.endBook; b++)
            _BookTile(plan: plan, bookIndex: b),
        ],
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final Plan plan;
  final PlanStats stats;

  const _ProgressHeader({required this.plan, required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String deadline;
    if (stats.isComplete) {
      deadline = 'Finished — ends ${formatDate(plan.endDate)}';
    } else if (stats.isOverdue) {
      deadline = 'End date passed (${formatDate(plan.endDate)}) — '
          'edit the plan to pick a new date';
    } else {
      deadline = '${stats.daysLeft} ${stats.daysLeft == 1 ? 'day' : 'days'} '
          'left · ends ${formatDate(plan.endDate)}';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${formatInt(stats.readCount)} of '
                    '${formatInt(stats.totalChapters)} chapters',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${(stats.progress * 100).toStringAsFixed(1)}%',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: stats.progress,
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
            ),
            const SizedBox(height: 8),
            Text(
              '${formatInt(stats.totalWords - stats.readWords)} words to go',
              style: theme.textTheme.bodySmall,
            ),
            Text(deadline, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _CompletedCard extends StatelessWidget {
  const _CompletedCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.emoji_events, size: 48, color: Colors.amber),
            const SizedBox(height: 8),
            Text('Plan complete!',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text('Every chapter has been read. '
                'Restart the plan from the menu to read it again.'),
          ],
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  final Plan plan;
  final List<int> todayIndices;
  final bool isOverdue;

  const _TodayCard({
    required this.plan,
    required this.todayIndices,
    required this.isOverdue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = context.read<PlanStore>();
    final chapters = [for (final i in todayIndices) allChapters[i]];
    final words = chapters.fold(0, (sum, c) => sum + c.words);
    final allDone =
        chapters.isNotEmpty && chapters.every((c) => plan.isRead(c.globalIndex));

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isOverdue ? 'Remaining' : "Today's reading",
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${chapters.length} chapters · ~${formatInt(words)} words',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            if (allDone)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    const Expanded(
                        child: Text('Done for today — see you tomorrow!')),
                  ],
                ),
              ),
            for (final c in chapters)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(c.reference),
                subtitle: Text('~${formatInt(c.words)} words'),
                value: plan.isRead(c.globalIndex),
                onChanged: (_) => store.toggleChapter(plan, c.globalIndex),
              ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  final List<ScheduleDay> upcoming;

  const _UpcomingCard({required this.upcoming});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = upcoming.take(3).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Coming up', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final day in preview)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${formatDate(day.date)}:  '
                  '${day.chapters.first.reference}'
                  '${day.chapters.length > 1 ? ' – ${day.chapters.last.reference}' : ''}'
                  '  (${day.chapters.length} ch)',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            Text(
              'Portions rebalance automatically as you read.',
              style: theme.textTheme.bodySmall!.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookTile extends StatelessWidget {
  final Plan plan;
  final int bookIndex;

  const _BookTile({required this.plan, required this.bookIndex});

  @override
  Widget build(BuildContext context) {
    final store = context.read<PlanStore>();
    final book = kjvBooks[bookIndex];
    final start = bookStartIndex[bookIndex];
    final readInBook = Iterable<int>.generate(book.chapterCount)
        .where((c) => plan.isRead(start + c))
        .length;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ExpansionTile(
        shape: const Border(),
        title: Text(book.name),
        subtitle: Text('$readInBook / ${book.chapterCount} read'),
        trailing: readInBook == book.chapterCount
            ? Icon(Icons.check_circle,
                color: Theme.of(context).colorScheme.primary)
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var c = 0; c < book.chapterCount; c++)
                  _ChapterDot(
                    number: c + 1,
                    read: plan.isRead(start + c),
                    onTap: () => store.toggleChapter(plan, start + c),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChapterDot extends StatelessWidget {
  final int number;
  final bool read;
  final VoidCallback onTap;

  const _ChapterDot({
    required this.number,
    required this.read,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: read ? scheme.primary : scheme.surfaceContainerHighest,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Text(
              '$number',
              style: TextStyle(
                color: read ? scheme.onPrimary : scheme.onSurfaceVariant,
                fontWeight: read ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
