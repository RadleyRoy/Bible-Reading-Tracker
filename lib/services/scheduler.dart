import 'dart:math';

import '../models/plan.dart';

/// The chapters assigned to one calendar day.
class ScheduleDay {
  final DateTime date;
  final List<ChapterRef> chapters;

  ScheduleDay(this.date, this.chapters);

  int get words => chapters.fold(0, (sum, c) => sum + c.words);
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Distributes [unread] chapters (in reading order) across the days from
/// [today] through [endDate], equalizing each day's word count.
///
/// The split is recomputed from whatever is still unread, so the schedule
/// automatically rebalances as chapters are marked read or days pass.
/// If the end date has passed, everything lands on today.
List<ScheduleDay> buildSchedule({
  required List<ChapterRef> unread,
  required DateTime today,
  required DateTime endDate,
}) {
  if (unread.isEmpty) return [];

  final start = dateOnly(today);
  final days = max(1, dateOnly(endDate).difference(start).inDays + 1);

  var remainingWords = unread.fold(0, (sum, c) => sum + c.words);
  var index = 0;
  final schedule = <ScheduleDay>[];

  for (var d = 0; d < days && index < unread.length; d++) {
    final remainingDays = days - d;
    final dayChapters = <ChapterRef>[];
    var dayWords = 0;

    if (remainingDays == 1) {
      dayChapters.addAll(unread.sublist(index));
      index = unread.length;
    } else {
      final target = remainingWords / remainingDays;
      while (index < unread.length) {
        final next = unread[index].words;
        if (dayChapters.isNotEmpty) {
          // Chapters are atomic: include the chapter that crosses the
          // target only if that lands closer to the target than stopping.
          final undershoot = target - dayWords;
          final overshoot = (dayWords + next) - target;
          if (dayWords + next > target && overshoot >= undershoot) break;
        }
        dayChapters.add(unread[index]);
        dayWords += next;
        index++;
      }
    }

    remainingWords -= dayChapters.fold(0, (sum, c) => sum + c.words);
    schedule.add(ScheduleDay(start.add(Duration(days: d)), dayChapters));
  }

  return schedule;
}

/// Pins the portion for today on [plan] if it isn't already pinned.
///
/// The assignment is computed once per calendar day from whatever is
/// unread at that moment and then kept for the rest of the day, so
/// checking off today's chapters never reshuffles the schedule. It is
/// recomputed when the day changes, after a restart or edit (see
/// [Plan.invalidateAssignment]), or when a chapter is un-read on a day
/// whose portion was empty.
///
/// Returns true when a new assignment was computed.
bool ensureTodayAssignment(Plan plan, DateTime now) {
  final today = dateOnly(now);
  final upToDate =
      plan.assignedDate == today &&
      (plan.assignedChapters.isNotEmpty || plan.unreadChapters.isEmpty);
  if (upToDate) return false;

  final schedule = buildSchedule(
    unread: plan.unreadChapters,
    today: today,
    endDate: plan.endDate,
  );
  plan.assignedDate = today;
  plan.assignedChapters = schedule.isEmpty
      ? <int>[]
      : [for (final c in schedule.first.chapters) c.globalIndex];
  return true;
}

/// Derived, display-ready numbers for a plan as of [now].
class PlanStats {
  final int totalChapters;
  final int readCount;
  final int totalWords;
  final int readWords;
  final int daysLeft;
  final ScheduleDay? today;
  final List<ScheduleDay> upcoming;

  PlanStats({
    required this.totalChapters,
    required this.readCount,
    required this.totalWords,
    required this.readWords,
    required this.daysLeft,
    required this.today,
    required this.upcoming,
  });

  double get progress => totalChapters == 0 ? 0 : readCount / totalChapters;
  bool get isComplete => readCount >= totalChapters;
  bool get isOverdue => daysLeft <= 0 && !isComplete;
}

PlanStats computeStats(Plan plan, DateTime now) {
  ensureTodayAssignment(plan, now);

  final chapters = plan.chapters;
  final totalWords = chapters.fold(0, (sum, c) => sum + c.words);
  final readWords = chapters
      .where((c) => plan.isRead(c.globalIndex))
      .fold(0, (sum, c) => sum + c.words);

  final today = dateOnly(now);
  final assigned = plan.assignedChapters.toSet();
  final todayPortion = plan.assignedChapters.isEmpty
      ? null
      : ScheduleDay(today, [
          for (final i in plan.assignedChapters) allChapters[i],
        ]);

  // Days after today are balanced over everything unread that is not part
  // of today's pinned portion, so they only move when chapters outside
  // today's range are marked read or unread.
  final upcoming = buildSchedule(
    unread: plan.unreadChapters
        .where((c) => !assigned.contains(c.globalIndex))
        .toList(),
    today: today.add(const Duration(days: 1)),
    endDate: plan.endDate,
  );

  return PlanStats(
    totalChapters: chapters.length,
    readCount: plan.readChapters.length,
    totalWords: totalWords,
    readWords: readWords,
    daysLeft: dateOnly(plan.endDate).difference(today).inDays + 1,
    today: todayPortion,
    upcoming: upcoming,
  );
}
