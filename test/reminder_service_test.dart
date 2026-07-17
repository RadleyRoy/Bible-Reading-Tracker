import 'package:bible_reading/services/reminder_service.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to off at 7:00', () async {
    final service = ReminderService(supported: false);
    await service.load();
    expect(service.enabled, isFalse);
    expect(service.time, const TimeOfDay(hour: 7, minute: 0));
  });

  test('enabled state and time survive a reload', () async {
    final service = ReminderService(supported: false);
    await service.load();
    expect(await service.setEnabled(true), isTrue);
    await service.setTime(const TimeOfDay(hour: 21, minute: 30));

    final reloaded = ReminderService(supported: false);
    await reloaded.load();
    expect(reloaded.enabled, isTrue);
    expect(reloaded.time, const TimeOfDay(hour: 21, minute: 30));
  });

  test('disabling persists', () async {
    SharedPreferences.setMockInitialValues({'reminder_enabled': true});
    final service = ReminderService(supported: false);
    await service.load();
    expect(service.enabled, isTrue);
    await service.setEnabled(false);

    final reloaded = ReminderService(supported: false);
    await reloaded.load();
    expect(reloaded.enabled, isFalse);
  });
}
