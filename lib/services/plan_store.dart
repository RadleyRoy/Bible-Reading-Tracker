import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/plan.dart';
import 'scheduler.dart';

/// Owns the list of plans and persists it as JSON in shared preferences.
class PlanStore extends ChangeNotifier {
  static const _prefsKey = 'plans_v1';

  final List<Plan> _plans = [];
  bool _loaded = false;

  List<Plan> get plans => List.unmodifiable(_plans);
  bool get isLoaded => _loaded;

  Plan? planById(String id) {
    for (final p in _plans) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    _plans.clear();
    if (raw != null) {
      final decoded = jsonDecode(raw) as List;
      _plans.addAll(
        decoded.map((e) => Plan.fromJson(e as Map<String, dynamic>)),
      );
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> addPlan(Plan plan) async {
    _plans.add(plan);
    await _persist();
  }

  /// Persists in-place edits to [plan] (name, dates, book range).
  Future<void> updatePlan(Plan plan) async {
    plan.pruneReadChapters();
    plan.invalidateAssignment();
    await _persist();
  }

  Future<void> deletePlan(String id) async {
    _plans.removeWhere((p) => p.id == id);
    await _persist();
  }

  Future<void> toggleChapter(Plan plan, int globalIndex) async {
    // Pin today's portion from the pre-toggle state so the toggle can
    // never move chapters in or out of today's list.
    ensureTodayAssignment(plan, DateTime.now());
    if (!plan.readChapters.remove(globalIndex)) {
      plan.readChapters.add(globalIndex);
    }
    await _persist();
  }

  /// Marks a chapter read from the reader (no-op if already read).
  Future<void> markRead(Plan plan, int globalIndex) async {
    if (plan.readChapters.contains(globalIndex)) return;
    ensureTodayAssignment(plan, DateTime.now());
    plan.readChapters.add(globalIndex);
    await _persist();
  }

  /// Marks every chapter unread so the plan starts over.
  Future<void> restartPlan(Plan plan) async {
    plan.readChapters.clear();
    plan.invalidateAssignment();
    plan.startDate = DateTime.now();
    await _persist();
  }

  Future<void> _persist() async {
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(_plans.map((p) => p.toJson()).toList()),
    );
  }
}
