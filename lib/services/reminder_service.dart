import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// The optional daily "time to read" notification.
///
/// Preferences always persist; actual scheduling only happens where the
/// notifications plugin is supported (Android — not the web preview, and
/// not in widget tests, which pass [supported]: false).
class ReminderService extends ChangeNotifier {
  static const _enabledKey = 'reminder_enabled';
  static const _hourKey = 'reminder_hour';
  static const _minuteKey = 'reminder_minute';
  static const _notificationId = 7;

  final bool supported;
  FlutterLocalNotificationsPlugin? _plugin;
  bool _initialized = false;

  bool _enabled = false;
  TimeOfDay _time = const TimeOfDay(hour: 7, minute: 0);

  ReminderService({bool? supported}) : supported = supported ?? !kIsWeb;

  bool get enabled => _enabled;
  TimeOfDay get time => _time;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? false;
    _time = TimeOfDay(
      hour: prefs.getInt(_hourKey) ?? 7,
      minute: prefs.getInt(_minuteKey) ?? 0,
    );
    notifyListeners();
    // Re-assert the schedule on startup; scheduling is idempotent.
    if (_enabled) await _schedule();
  }

  /// Turns the reminder on or off. Returns false when turning on fails
  /// because the notification permission was denied.
  Future<bool> setEnabled(bool value) async {
    if (value && supported) {
      if (!await _ensureReady()) return false;
      await _schedule();
    }
    if (!value) await _cancel();
    _enabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
    return true;
  }

  Future<void> setTime(TimeOfDay value) async {
    _time = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_hourKey, value.hour);
    await prefs.setInt(_minuteKey, value.minute);
    if (_enabled) await _schedule();
  }

  Future<bool> _ensureReady() async {
    if (!supported) return true;
    if (!_initialized) {
      tz_data.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (_) {
        // Fall back to the package default; the reminder still fires daily.
      }
      _plugin = FlutterLocalNotificationsPlugin();
      await _plugin!.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _initialized = true;
    }
    final android = _plugin!
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? true;
  }

  Future<void> _schedule() async {
    if (!supported || !await _ensureReady()) return;
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      _time.hour,
      _time.minute,
    );
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    await _plugin!.zonedSchedule(
      id: _notificationId,
      title: 'Bible Reading',
      body: "Today's chapters are waiting — keep your plan on track.",
      scheduledDate: next,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          'Daily reminder',
          channelDescription: 'A daily reminder to read your Bible',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _cancel() async {
    if (!supported || !_initialized) return;
    await _plugin!.cancel(id: _notificationId);
  }
}
