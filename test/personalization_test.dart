import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warungpilot/models.dart';
import 'package:warungpilot/services/store.dart';

import 'ledger_test.dart' show FastExtractor;

Future<AppStore> scenario(OwnerGoal goal) async {
  final s = AppStore(extractor: FastExtractor());
  await s.load();
  await s.signInDemo();
  await s.loadDemoScenario(goal);
  return s;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('same data, different goal → different top recommendation', () async {
    final stock = await scenario(OwnerGoal.stockAvailability);
    final profit = await scenario(OwnerGoal.profitability);
    expect(stock.insights.first.kind, InsightKind.lowStock);
    expect(stock.insights.first.title, contains('Aqua'));
    expect(goalKinds[OwnerGoal.profitability], contains(profit.insights.first.kind));
    expect(profit.insights.first.id, isNot(stock.insights.first.id));
    expect(stock.insights.first.whyForYou, contains(ownerGoalLabels[OwnerGoal.stockAvailability]!));
  });

  test('demo scenario keeps ledger rules: revenue from two confirmed days only', () async {
    final s = await scenario(OwnerGoal.stockAvailability);
    expect(s.verifiedRecordDays, 2);
    expect(s.sales.length, 2);
    expect(s.products.firstWhere((p) => p.name == 'Aqua 600ml').qty, 7);
    expect(s.summaryForDay(s.now).hasSales, isFalse);
  });

  test('not-useful feedback hides the insight and is persisted', () async {
    final s = await scenario(OwnerGoal.stockAvailability);
    final top = s.insights.first;
    await s.rateInsight(top, false);
    expect(s.insights.any((i) => i.id == top.id), isFalse);
    expect(s.hiddenInsightCount, 1);

    final reloaded = AppStore(extractor: FastExtractor());
    await reloaded.load();
    expect(reloaded.feedbackFor(top.id)?.useful, isFalse);
    expect(reloaded.insights.any((i) => i.id == top.id), isFalse);
  });

  test('useful feedback on a kind raises similar insights', () async {
    final s = await scenario(OwnerGoal.stockAvailability);
    final missing = s.insights.firstWhere((i) => i.kind == InsightKind.missingCost);
    final before = s.insightScore(missing);
    await s.rateInsight(missing, true);
    expect(s.insightScore(s.insights.firstWhere((i) => i.id == missing.id)), greaterThan(before));
  });

  test('confirmed correction becomes a learned alias used next time', () async {
    final s = await scenario(OwnerGoal.stockAvailability);
    final teh = s.products.firstWhere((p) => p.name == 'Teh Pucuk');
    final doc = await s.createDocument(DocKind.dailySales);
    await s.extract(doc.id);
    final row = doc.rows.firstWhere((r) => r.name == 'Teh pcuk');
    expect(row.unclear, isTrue);
    row.productId = teh.id;
    expect((await s.confirmDocument(doc.id)).ok, isTrue);
    expect(s.profile!.aliases['teh pcuk'], teh.id);

    // Next day's note with the same spelling is recognized confidently.
    s.clock = () => DateTime.now().add(const Duration(days: 1));
    final doc2 = await s.createDocument(DocKind.dailySales);
    await s.extract(doc2.id);
    final row2 = doc2.rows.firstWhere((r) => r.name == 'Teh pcuk');
    expect(row2.learned, isTrue);
    expect(row2.unclear, isFalse);
    expect(row2.productId, teh.id);
  });

  test('reset learning clears aliases and feedback but keeps goal and data', () async {
    final s = await scenario(OwnerGoal.profitability);
    expect(s.profile!.aliases, isNotEmpty);
    expect(s.feedback, isNotEmpty);
    final salesBefore = s.sales.length;
    await s.resetLearning();
    expect(s.profile!.aliases, isEmpty);
    expect(s.feedback, isEmpty);
    expect(s.profile!.goal, OwnerGoal.profitability);
    expect(s.sales.length, salesBefore);
    expect(s.products.firstWhere((p) => p.name == 'Teh Pucuk').aliases, isEmpty);
  });

  test('goal-relevant missions come first; skipped daily mission hidden today', () async {
    final s = await scenario(OwnerGoal.profitability);
    expect(s.missions.first.id, anyOf('daily_costs', 'daily_expense'));
    await s.skipMission('daily_costs');
    expect(s.missions.any((m) => m.id == 'daily_costs'), isFalse);
  });
}
