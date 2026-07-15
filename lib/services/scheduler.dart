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
  final chapters = plan.chapters;
  final totalWords = chapters.fold(0, (sum, c) => sum + c.words);
  final readWords = chapters
      .where((c) => plan.isRead(c.globalIndex))
      .fold(0, (sum, c) => sum + c.words);

  final schedule = buildSchedule(
    unread: plan.unreadChapters,
    today: now,
    endDate: plan.endDate,
  );

  return PlanStats(
    totalChapters: chapters.length,
    readCount: plan.readChapters.length,
    totalWords: totalWords,
    readWords: readWords,
    daysLeft: dateOnly(plan.endDate).difference(dateOnly(now)).inDays + 1,
    today: schedule.isEmpty ? null : schedule.first,
    upcoming: schedule.length > 1 ? schedule.sublist(1) : const [],
  );
}
