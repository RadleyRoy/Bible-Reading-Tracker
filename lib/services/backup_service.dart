import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/kjv_data.dart';
import '../models/plan.dart';

/// Raised when a file is not a usable backup. [message] is shown to the user.
class BackupFormatException implements Exception {
  final String message;

  const BackupFormatException(this.message);

  @override
  String toString() => message;
}

/// What a backup file contains, for the confirmation dialog.
class BackupSummary {
  final int planCount;
  final List<String> planNames;
  final int chaptersRead;
  final DateTime? exportedAt;

  const BackupSummary({
    required this.planCount,
    required this.planNames,
    required this.chaptersRead,
    required this.exportedAt,
  });
}

/// Exports and restores everything the app stores, so a reinstall (or a new
/// phone) can pick up exactly where the old one left off.
///
/// The document is plain JSON with a [formatVersion] so older files stay
/// readable. Restoring replaces all app data; it is validated up front so a
/// wrong or corrupt file fails cleanly instead of half-applying.
class BackupService {
  BackupService._();

  static const _appId = 'bible-reading-tracker';
  static const formatVersion = 1;

  // Preference keys owned by the other services.
  static const _plansKey = 'plans_v1';
  static const _fontFamilyKey = 'reader_font_family';
  static const _fontSizeKey = 'reader_font_size';
  static const _autoMarkKey = 'reader_auto_mark';
  static const _reminderEnabledKey = 'reminder_enabled';
  static const _reminderHourKey = 'reminder_hour';
  static const _reminderMinuteKey = 'reminder_minute';
  static const _lastReadKey = 'last_read_position';

  /// Serialises all app data into a backup document.
  static Future<String> buildBackupJson() async {
    final prefs = await SharedPreferences.getInstance();
    final plansRaw = prefs.getString(_plansKey);

    return const JsonEncoder.withIndent('  ').convert({
      'app': _appId,
      'formatVersion': formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'plans': plansRaw == null ? [] : jsonDecode(plansRaw),
      'settings': {
        'fontFamily': prefs.getString(_fontFamilyKey),
        'fontSize': prefs.getDouble(_fontSizeKey),
        'autoMark': prefs.getBool(_autoMarkKey),
      },
      'reminder': {
        'enabled': prefs.getBool(_reminderEnabledKey),
        'hour': prefs.getInt(_reminderHourKey),
        'minute': prefs.getInt(_reminderMinuteKey),
      },
      'lastReadPosition': prefs.getInt(_lastReadKey),
    });
  }

  /// Parses and validates [json], returning what it holds.
  ///
  /// Throws [BackupFormatException] for anything that is not a backup this
  /// app can restore.
  static BackupSummary inspectBackup(String json) {
    final Map<String, dynamic> doc;
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic>) {
        throw const BackupFormatException(
          "This doesn't look like a Bible backup.",
        );
      }
      doc = decoded;
    } on FormatException {
      throw const BackupFormatException(
        "That file isn't readable as a backup.",
      );
    }

    if (doc['app'] != _appId) {
      throw const BackupFormatException(
        "This doesn't look like a Bible backup.",
      );
    }
    final version = doc['formatVersion'];
    if (version is! int || version > formatVersion) {
      throw const BackupFormatException(
        'This backup was made by a newer version of the app. '
        'Update Bible and try again.',
      );
    }

    final plansRaw = doc['plans'];
    if (plansRaw is! List) {
      throw const BackupFormatException('This backup is missing its plans.');
    }

    final names = <String>[];
    var chaptersRead = 0;
    for (final entry in plansRaw) {
      if (entry is! Map<String, dynamic>) {
        throw const BackupFormatException('This backup is damaged.');
      }
      final Plan plan;
      try {
        plan = Plan.fromJson(entry);
      } catch (_) {
        throw const BackupFormatException('This backup is damaged.');
      }
      // Guard the indices the whole app trusts, so a corrupt file cannot
      // crash the reader or scheduler later.
      final books = kjvBooks.length;
      if (plan.startBook < 0 ||
          plan.endBook >= books ||
          plan.startBook > plan.endBook ||
          plan.readChapters.any((i) => i < 0 || i >= allChapters.length)) {
        throw const BackupFormatException(
          'This backup refers to Bible chapters that do not exist.',
        );
      }
      names.add(plan.name);
      chaptersRead += plan.readChapters.length;
    }

    final exportedAtRaw = doc['exportedAt'];
    return BackupSummary(
      planCount: plansRaw.length,
      planNames: names,
      chaptersRead: chaptersRead,
      exportedAt: exportedAtRaw is String
          ? DateTime.tryParse(exportedAtRaw)
          : null,
    );
  }

  /// Replaces all app data with the contents of [json].
  ///
  /// Validates first, so a bad file leaves existing data untouched. Callers
  /// must reload the services afterwards (see `restoreAndReload` usage in
  /// the settings screen).
  static Future<void> restoreBackup(String json) async {
    inspectBackup(json); // throws before anything is written
    final doc = jsonDecode(json) as Map<String, dynamic>;
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_plansKey, jsonEncode(doc['plans']));

    final settings = doc['settings'];
    final reminder = doc['reminder'];
    await _restoreString(
      prefs,
      _fontFamilyKey,
      settings is Map ? settings['fontFamily'] : null,
    );
    await _restoreDouble(
      prefs,
      _fontSizeKey,
      settings is Map ? settings['fontSize'] : null,
    );
    await _restoreBool(
      prefs,
      _autoMarkKey,
      settings is Map ? settings['autoMark'] : null,
    );
    await _restoreBool(
      prefs,
      _reminderEnabledKey,
      reminder is Map ? reminder['enabled'] : null,
    );
    await _restoreInt(
      prefs,
      _reminderHourKey,
      reminder is Map ? reminder['hour'] : null,
    );
    await _restoreInt(
      prefs,
      _reminderMinuteKey,
      reminder is Map ? reminder['minute'] : null,
    );
    await _restoreInt(prefs, _lastReadKey, doc['lastReadPosition']);
  }

  // A null in the backup means "unset", so the key is removed rather than
  // left over from whatever was on this device before.
  static Future<void> _restoreString(
    SharedPreferences prefs,
    String key,
    Object? value,
  ) => value is String ? prefs.setString(key, value) : prefs.remove(key);

  static Future<void> _restoreDouble(
    SharedPreferences prefs,
    String key,
    Object? value,
  ) =>
      value is num ? prefs.setDouble(key, value.toDouble()) : prefs.remove(key);

  static Future<void> _restoreInt(
    SharedPreferences prefs,
    String key,
    Object? value,
  ) => value is num ? prefs.setInt(key, value.toInt()) : prefs.remove(key);

  static Future<void> _restoreBool(
    SharedPreferences prefs,
    String key,
    Object? value,
  ) => value is bool ? prefs.setBool(key, value) : prefs.remove(key);
}
