import 'dart:convert';

import 'package:bible_reading/models/plan.dart';
import 'package:bible_reading/services/backup_service.dart';
import 'package:bible_reading/services/plan_store.dart';
import 'package:bible_reading/services/reader_settings.dart';
import 'package:bible_reading/services/reminder_service.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Fills the app with representative data and returns the plan used.
  Future<Plan> seedApp() async {
    final store = PlanStore();
    await store.load();
    final plan = Plan(
      id: 'p1',
      name: 'New Testament in 90 days',
      startBook: 39,
      endBook: 65,
      startDate: DateTime(2026, 7, 15),
      endDate: DateTime(2026, 10, 12),
    );
    plan.readChapters.addAll([929, 930, 931]);
    plan.assignedDate = DateTime(2026, 7, 18);
    plan.assignedChapters = [932, 933];
    await store.addPlan(plan);

    final settings = ReaderSettings();
    await settings.load();
    await settings.setFontFamily('Lora');
    await settings.setFontSize(22);
    await settings.setAutoMark(true);

    final reminder = ReminderService(supported: false);
    await reminder.load();
    await reminder.setEnabled(true);
    await reminder.setTime(const TimeOfDay(hour: 21, minute: 30));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_read_position', 100);
    return plan;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('export', () {
    test('captures plans, settings, reminder, and position', () async {
      await seedApp();
      final doc =
          jsonDecode(await BackupService.buildBackupJson())
              as Map<String, dynamic>;

      expect(doc['app'], 'bible-reading-tracker');
      expect(doc['formatVersion'], BackupService.formatVersion);
      expect(DateTime.tryParse(doc['exportedAt'] as String), isNotNull);
      expect((doc['plans'] as List), hasLength(1));
      expect(doc['settings']['fontFamily'], 'Lora');
      expect(doc['settings']['fontSize'], 22);
      expect(doc['settings']['autoMark'], isTrue);
      expect(doc['reminder']['enabled'], isTrue);
      expect(doc['reminder']['hour'], 21);
      expect(doc['reminder']['minute'], 30);
      expect(doc['lastReadPosition'], 100);
    });

    test('works on a fresh install with no data', () async {
      final json = await BackupService.buildBackupJson();
      final summary = BackupService.inspectBackup(json);
      expect(summary.planCount, 0);
      expect(summary.chaptersRead, 0);
    });
  });

  group('round trip', () {
    test('restores every service exactly after a wipe', () async {
      final original = await seedApp();
      final json = await BackupService.buildBackupJson();

      // Simulate a reinstall.
      SharedPreferences.setMockInitialValues({});
      final empty = PlanStore();
      await empty.load();
      expect(empty.plans, isEmpty);

      await BackupService.restoreBackup(json);

      final store = PlanStore();
      await store.load();
      expect(store.plans, hasLength(1));
      final restored = store.plans.single;
      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.startBook, 39);
      expect(restored.endBook, 65);
      expect(restored.startDate, original.startDate);
      expect(restored.endDate, original.endDate);
      expect(restored.readChapters, {929, 930, 931});
      expect(restored.assignedDate, DateTime(2026, 7, 18));
      expect(restored.assignedChapters, [932, 933]);

      final settings = ReaderSettings();
      await settings.load();
      expect(settings.fontFamily, 'Lora');
      expect(settings.fontSize, 22);
      expect(settings.autoMark, isTrue);

      final reminder = ReminderService(supported: false);
      await reminder.load();
      expect(reminder.enabled, isTrue);
      expect(reminder.time, const TimeOfDay(hour: 21, minute: 30));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('last_read_position'), 100);
    });

    test('restoring defaults clears settings left on the device', () async {
      // A backup taken on a fresh install...
      final defaults = await BackupService.buildBackupJson();
      // ...restored over a device with customised settings.
      await seedApp();
      await BackupService.restoreBackup(defaults);

      final settings = ReaderSettings();
      await settings.load();
      expect(settings.fontFamily, isNull);
      expect(settings.fontSize, ReaderSettings.defaultSize);
      expect(settings.autoMark, isFalse);

      final store = PlanStore();
      await store.load();
      expect(store.plans, isEmpty);
    });

    test('summary describes the file for the confirmation dialog', () async {
      await seedApp();
      final summary = BackupService.inspectBackup(
        await BackupService.buildBackupJson(),
      );
      expect(summary.planCount, 1);
      expect(summary.planNames, ['New Testament in 90 days']);
      expect(summary.chaptersRead, 3);
      expect(summary.exportedAt, isNotNull);
    });
  });

  group('rejects bad files without touching existing data', () {
    /// Asserts [json] is refused and the seeded plan survives.
    Future<void> expectRejected(String json) async {
      await seedApp();
      expect(
        () => BackupService.inspectBackup(json),
        throwsA(isA<BackupFormatException>()),
      );
      await expectLater(
        BackupService.restoreBackup(json),
        throwsA(isA<BackupFormatException>()),
      );
      final store = PlanStore();
      await store.load();
      expect(store.plans, hasLength(1), reason: 'existing data must survive');
      expect(store.plans.single.readChapters, {929, 930, 931});
    }

    test('plain text', () => expectRejected('not json at all'));

    test('unrelated JSON', () => expectRejected('{"hello":"world"}'));

    test('JSON array', () => expectRejected('[1,2,3]'));

    test(
      'another app\'s backup',
      () => expectRejected(
        jsonEncode({'app': 'some-other-app', 'formatVersion': 1, 'plans': []}),
      ),
    );

    test(
      'newer format version',
      () => expectRejected(
        jsonEncode({
          'app': 'bible-reading-tracker',
          'formatVersion': BackupService.formatVersion + 1,
          'plans': [],
        }),
      ),
    );

    test(
      'missing plans list',
      () => expectRejected(
        jsonEncode({'app': 'bible-reading-tracker', 'formatVersion': 1}),
      ),
    );

    test(
      'out-of-range book index',
      () => expectRejected(
        jsonEncode({
          'app': 'bible-reading-tracker',
          'formatVersion': 1,
          'plans': [
            {
              'id': 'x',
              'name': 'Bad',
              'startBook': 0,
              'endBook': 99,
              'startDate': '2026-07-15T00:00:00.000',
              'endDate': '2026-10-12T00:00:00.000',
              'readChapters': <int>[],
            },
          ],
        }),
      ),
    );

    test(
      'chapter index beyond the Bible',
      () => expectRejected(
        jsonEncode({
          'app': 'bible-reading-tracker',
          'formatVersion': 1,
          'plans': [
            {
              'id': 'x',
              'name': 'Bad',
              'startBook': 0,
              'endBook': 65,
              'startDate': '2026-07-15T00:00:00.000',
              'endDate': '2026-10-12T00:00:00.000',
              'readChapters': [99999],
            },
          ],
        }),
      ),
    );

    test(
      'malformed plan entry',
      () => expectRejected(
        jsonEncode({
          'app': 'bible-reading-tracker',
          'formatVersion': 1,
          'plans': [
            {'id': 'x'},
          ],
        }),
      ),
    );
  });
}
