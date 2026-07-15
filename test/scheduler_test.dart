import 'package:bible_reading/data/kjv_data.dart';
import 'package:bible_reading/models/plan.dart';
import 'package:bible_reading/services/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 7, 15);

  Plan makePlan({int startBook = 0, int endBook = 65, int days = 365}) => Plan(
        id: 'test',
        name: 'Test',
        startBook: startBook,
        endBook: endBook,
        startDate: today,
        endDate: today.add(Duration(days: days - 1)),
      );

  group('KJV data', () {
    test('has 66 books, 1,189 chapters, and the expected word total', () {
      expect(kjvBooks.length, 66);
      expect(allChapters.length, 1189);
      expect(allChapters.length, kjvTotalChapters);
      expect(allChapters.fold(0, (s, c) => s + c.words), kjvTotalWords);
    });

    test('testament and book ranges are correct', () {
      expect(makePlan(endBook: 38).totalChapters, 929); // Old Testament
      expect(makePlan(startBook: 39).totalChapters, 260); // New Testament
      expect(kjvBooks[18].name, 'Psalms');
      expect(kjvBooks[18].chapterCount, 150);
    });
  });

  group('buildSchedule', () {
    test('covers every chapter exactly once, in order', () {
      final plan = makePlan();
      final schedule = buildSchedule(
        unread: plan.unreadChapters,
        today: today,
        endDate: plan.endDate,
      );
      final flat = [for (final d in schedule) ...d.chapters];
      expect(flat.length, 1189);
      for (var i = 0; i < flat.length; i++) {
        expect(flat[i].globalIndex, i);
      }
      expect(schedule.length, 365);
    });

    test('balances words across days', () {
      final plan = makePlan();
      final schedule = buildSchedule(
        unread: plan.unreadChapters,
        today: today,
        endDate: plan.endDate,
      );
      final mean = kjvTotalWords / 365;
      final largestChapter =
          allChapters.map((c) => c.words).reduce((a, b) => a > b ? a : b);
      for (final day in schedule) {
        expect(day.chapters, isNotEmpty);
        // No day may deviate from the average by more than one chapter.
        expect(day.words, lessThan(mean + largestChapter));
        expect(day.words, greaterThan(mean - largestChapter));
      }
    });

    test('rebalances after chapters are read', () {
      final plan = makePlan(days: 10, startBook: 39, endBook: 39); // Matthew
      final first = buildSchedule(
        unread: plan.unreadChapters,
        today: today,
        endDate: plan.endDate,
      );
      // Read everything assigned to the first two days.
      for (final day in first.take(2)) {
        for (final c in day.chapters) {
          plan.readChapters.add(c.globalIndex);
        }
      }
      // Still on day one: the remaining chapters spread over all 10 days.
      final rebalanced = buildSchedule(
        unread: plan.unreadChapters,
        today: today,
        endDate: plan.endDate,
      );
      final flat = [for (final d in rebalanced) ...d.chapters];
      expect(flat.length, 28 - plan.readChapters.length);
      expect(rebalanced.length, 10);
      expect(flat.first.globalIndex,
          first.take(2).last.chapters.last.globalIndex + 1);
    });

    test('past end date puts everything on today', () {
      final plan = makePlan(days: 5, startBook: 42, endBook: 42); // John
      final schedule = buildSchedule(
        unread: plan.unreadChapters,
        today: today.add(const Duration(days: 30)),
        endDate: plan.endDate,
      );
      expect(schedule.length, 1);
      expect(schedule.single.chapters.length, 21);
    });

    test('single-day plan gets everything today', () {
      final plan = makePlan(days: 1, startBook: 64, endBook: 64); // Jude
      final schedule = buildSchedule(
        unread: plan.unreadChapters,
        today: today,
        endDate: plan.endDate,
      );
      expect(schedule.length, 1);
      expect(schedule.single.chapters.length, 1);
    });

    test('more days than chapters: at most one chapter per day, none lost',
        () {
      final plan = makePlan(days: 30, startBook: 49, endBook: 49); // Phil., 4 ch
      final schedule = buildSchedule(
        unread: plan.unreadChapters,
        today: today,
        endDate: plan.endDate,
      );
      final flat = [for (final d in schedule) ...d.chapters];
      expect(flat.length, 4);
      for (final day in schedule) {
        expect(day.chapters.length, lessThanOrEqualTo(2));
      }
    });

    test('empty unread list yields empty schedule', () {
      expect(
        buildSchedule(unread: [], today: today, endDate: today),
        isEmpty,
      );
    });
  });

  group('today assignment stability', () {
    test("reading today's chapters does not shift tomorrow", () {
      final plan = makePlan(days: 10, startBook: 39, endBook: 39); // Matthew
      final s1 = computeStats(plan, today);
      final todayList = s1.today!.chapters.map((c) => c.globalIndex).toList();
      final tomorrowFirst = s1.upcoming.first.chapters.first.globalIndex;
      expect(tomorrowFirst, todayList.last + 1);

      plan.readChapters.add(todayList.first);
      final s2 = computeStats(plan, today);
      expect(s2.today!.chapters.map((c) => c.globalIndex), todayList);
      expect(s2.upcoming.first.chapters.first.globalIndex, tomorrowFirst);

      // Unmarking it again also changes nothing.
      plan.readChapters.remove(todayList.first);
      final s3 = computeStats(plan, today);
      expect(s3.today!.chapters.map((c) => c.globalIndex), todayList);
      expect(s3.upcoming.first.chapters.first.globalIndex, tomorrowFirst);
    });

    test("reading into tomorrow's range shifts only the upcoming days", () {
      final plan = makePlan(days: 10, startBook: 39, endBook: 39);
      final s1 = computeStats(plan, today);
      final todayList = s1.today!.chapters.map((c) => c.globalIndex).toList();
      final tomorrowFirst = s1.upcoming.first.chapters.first.globalIndex;

      plan.readChapters.add(tomorrowFirst);
      final s2 = computeStats(plan, today);
      expect(s2.today!.chapters.map((c) => c.globalIndex), todayList);
      expect(s2.upcoming.first.chapters.first.globalIndex, tomorrowFirst + 1);
    });

    test('a new day gets a fresh assignment', () {
      final plan = makePlan(days: 10, startBook: 39, endBook: 39);
      final s1 = computeStats(plan, today);
      final todayList = s1.today!.chapters.map((c) => c.globalIndex).toList();
      plan.readChapters.addAll(todayList);

      final tomorrow = today.add(const Duration(days: 1));
      final s2 = computeStats(plan, tomorrow);
      expect(plan.assignedDate, tomorrow);
      expect(s2.today!.chapters.first.globalIndex, todayList.last + 1);
    });

    test('un-reading on a day with an empty portion assigns it to today', () {
      final plan = makePlan(days: 10, startBook: 64, endBook: 64); // Jude
      plan.readChapters.add(bookStartIndex[64]);
      expect(computeStats(plan, today).today, isNull);

      plan.readChapters.remove(bookStartIndex[64]);
      final stats = computeStats(plan, today);
      expect(stats.today!.chapters.single.globalIndex, bookStartIndex[64]);
    });
  });

  group('computeStats', () {
    test('reports progress, days left, and today portion', () {
      final plan = makePlan(days: 100, startBook: 39, endBook: 65); // NT
      plan.readChapters.addAll([bookStartIndex[39], bookStartIndex[39] + 1]);
      final stats = computeStats(plan, today);
      expect(stats.totalChapters, 260);
      expect(stats.readCount, 2);
      expect(stats.progress, closeTo(2 / 260, 1e-9));
      expect(stats.daysLeft, 100);
      expect(stats.today, isNotNull);
      expect(stats.today!.chapters.first.globalIndex, bookStartIndex[39] + 2);
      expect(stats.isComplete, isFalse);
      expect(stats.isOverdue, isFalse);
    });

    test('complete plan has no today portion', () {
      final plan = makePlan(days: 10, startBook: 64, endBook: 64);
      plan.readChapters.add(bookStartIndex[64]);
      final stats = computeStats(plan, today);
      expect(stats.isComplete, isTrue);
      expect(stats.today, isNull);
    });
  });
}
