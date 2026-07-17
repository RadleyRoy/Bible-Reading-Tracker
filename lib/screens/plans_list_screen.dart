import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/plan.dart';
import '../services/plan_store.dart';
import '../services/scheduler.dart';
import '../utils.dart';
import 'create_plan_screen.dart';
import 'plan_detail_screen.dart';
import 'reader_screen.dart';

class PlansListScreen extends StatelessWidget {
  const PlansListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<PlanStore>();

    return Scaffold(
      appBar: AppBar(title: const Text('Bible Reading Plans')),
      body: Column(
        children: [
          Expanded(
            child: !store.isLoaded
                ? const Center(child: CircularProgressIndicator())
                : store.plans.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: store.plans.length,
                    itemBuilder: (context, i) =>
                        _PlanCard(plan: store.plans[i]),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'created by Radley',
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreatePlanScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New plan'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No reading plans yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a plan by choosing what to read and when to '
              'finish. Your daily portions are balanced by word count.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Plan plan;

  const _PlanCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final stats = computeStats(plan, DateTime.now());
    final theme = Theme.of(context);

    final String statusLine;
    if (stats.isComplete) {
      statusLine = 'Completed — well done!';
    } else if (stats.isOverdue) {
      statusLine =
          'End date passed — ${formatInt(stats.totalChapters - stats.readCount)} chapters left';
    } else {
      final today = stats.today;
      statusLine = today == null
          ? 'Ends ${formatDate(plan.endDate)}'
          : 'Today: ${today.chapters.length} chapters (~${formatInt(today.words)} words) '
                '· ${stats.daysLeft} days left';
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PlanDetailScreen(planId: plan.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(plan.name, style: theme.textTheme.titleMedium),
                  ),
                  if (plan.nextUnreadChapter != null)
                    IconButton(
                      tooltip: 'Continue reading',
                      icon: const Icon(Icons.play_circle_outline),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReaderScreen(
                            globalIndex: plan.nextUnreadChapter!,
                            planId: plan.id,
                          ),
                        ),
                      ),
                    ),
                  PlanMenuButton(plan: plan),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: stats.progress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${formatInt(stats.readCount)} of ${formatInt(stats.totalChapters)} '
                      'chapters · ${(stats.progress * 100).toStringAsFixed(0)}%',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(statusLine, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Edit / restart / delete menu shared by the list card and detail screen.
class PlanMenuButton extends StatelessWidget {
  final Plan plan;

  /// Called after the plan is deleted.
  final VoidCallback? onDeleted;

  const PlanMenuButton({super.key, required this.plan, this.onDeleted});

  @override
  Widget build(BuildContext context) {
    final store = context.read<PlanStore>();

    return PopupMenuButton<String>(
      onSelected: (value) async {
        switch (value) {
          case 'edit':
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreatePlanScreen(existing: plan),
              ),
            );
          case 'restart':
            final ok = await confirm(
              context,
              title: 'Restart plan?',
              message:
                  'All ${formatInt(plan.readChapters.length)} read chapters in '
                  '"${plan.name}" will be marked unread and the plan starts over.',
              action: 'Restart',
            );
            if (ok) {
              await store.restartPlan(plan);
            }
          case 'delete':
            final ok = await confirm(
              context,
              title: 'Delete plan?',
              message:
                  '"${plan.name}" and its progress will be permanently '
                  'deleted.',
              action: 'Delete',
            );
            if (ok) {
              await store.deletePlan(plan.id);
              onDeleted?.call();
            }
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'edit', child: Text('Edit')),
        PopupMenuItem(value: 'restart', child: Text('Restart')),
        PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
  }
}
