import 'package:bible_reading/models/plan.dart';
import 'package:bible_reading/services/plan_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Plan makePlan() => Plan(
        id: '42',
        name: 'New Testament in 90 days',
        startBook: 39,
        endBook: 65,
        startDate: DateTime(2026, 7, 15),
        endDate: DateTime(2026, 10, 12),
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('plans survive a save/load round trip', () async {
    final store = PlanStore();
    await store.load();
    final plan = makePlan();
    plan.readChapters.addAll([929, 930, 955]);
    await store.addPlan(plan);

    final reloaded = PlanStore();
    await reloaded.load();
    expect(reloaded.plans, hasLength(1));
    final p = reloaded.plans.single;
    expect(p.id, '42');
    expect(p.name, 'New Testament in 90 days');
    expect(p.startBook, 39);
    expect(p.endBook, 65);
    expect(p.endDate, DateTime(2026, 10, 12));
    expect(p.readChapters, {929, 930, 955});
  });

  test('toggleChapter marks and unmarks', () async {
    final store = PlanStore();
    await store.load();
    final plan = makePlan();
    await store.addPlan(plan);

    await store.toggleChapter(plan, 929);
    expect(plan.isRead(929), isTrue);
    await store.toggleChapter(plan, 929);
    expect(plan.isRead(929), isFalse);
  });

  test('restartPlan clears all read chapters', () async {
    final store = PlanStore();
    await store.load();
    final plan = makePlan();
    plan.readChapters.addAll(List.generate(50, (i) => 929 + i));
    await store.addPlan(plan);

    await store.restartPlan(plan);
    expect(plan.readChapters, isEmpty);

    final reloaded = PlanStore();
    await reloaded.load();
    expect(reloaded.plans.single.readChapters, isEmpty);
  });

  test('deletePlan removes the plan', () async {
    final store = PlanStore();
    await store.load();
    await store.addPlan(makePlan());
    await store.deletePlan('42');
    expect(store.plans, isEmpty);

    final reloaded = PlanStore();
    await reloaded.load();
    expect(reloaded.plans, isEmpty);
  });

  test('editing the range prunes out-of-range read marks', () async {
    final store = PlanStore();
    await store.load();
    final plan = makePlan();
    plan.readChapters.addAll([0, 929]); // Genesis 1 (stale), Matthew 1
    await store.addPlan(plan);

    await store.updatePlan(plan);
    expect(plan.readChapters, {929});
  });
}
