import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warungpilot/models.dart';
import 'package:warungpilot/services/ai_extractor.dart';
import 'package:warungpilot/services/ledger.dart';
import 'package:warungpilot/services/store.dart';

/// Zero-delay extractor wrapping the demo output.
class FastExtractor implements AiExtractor {
  final _demo = DemoAiExtractor();
  @override
  Future<ExtractionResult> extract(
          {required DocKind kind, Uint8List? image, required List<Product> catalog, required int attempt}) =>
      _demo.extract(kind: kind, catalog: catalog, attempt: attempt);
}

Future<AppStore> seededStore() async {
  final s = AppStore(extractor: FastExtractor());
  await s.load();
  await s.signInDemo();
  await s.createBusiness(name: 'Warung Test', owner: 'Bu Test', city: 'Bandung');
  final doc = await s.createDocument(DocKind.openingStock);
  await s.extract(doc.id);
  // Drop the "Gula" row (unknown cost) for the clean PRD demo dataset.
  doc.rows.removeWhere((r) => r.name.startsWith('Gula'));
  final r = await s.confirmDocument(doc.id);
  expect(r.ok, isTrue);
  return s;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('moving average', () {
    test('PRD example: 10×2500 + 10×2700 = 2600', () {
      expect(movingAverageCost(oldQty: 10, oldAvg: 2500, addQty: 10, addCost: 2700), 2600);
    });
    test('unknown historical cost stays unknown, never zero', () {
      expect(movingAverageCost(oldQty: 10, oldAvg: null, addQty: 10, addCost: 2700), isNull);
    });
    test('unknown purchase cost makes average unknown', () {
      expect(movingAverageCost(oldQty: 10, oldAvg: 2500, addQty: 5, addCost: null), isNull);
    });
    test('empty stock takes new cost', () {
      expect(movingAverageCost(oldQty: 0, oldAvg: null, addQty: 5, addCost: 3000), 3000);
    });
  });

  test('PRD demo dataset: revenue 75k, COGS 55k, GP 20k, margin 26.67%', () async {
    final s = await seededStore();
    final doc = await s.createDocument(DocKind.dailySales);
    await s.extract(doc.id);
    // "teh pcuk" is low-confidence; user selects the right product.
    final teh = s.products.firstWhere((p) => p.name == 'Teh Pucuk');
    doc.rows[2].productId = teh.id;
    final r = await s.confirmDocument(doc.id);
    expect(r.ok, isTrue, reason: r.message);

    final sum = s.summaryForDay(s.now);
    expect(sum.revenue, 75000);
    expect(sum.knownCogs, 55000);
    expect(sum.grossProfit, 20000);
    expect(sum.grossMarginPct!.toStringAsFixed(2), '26.67');
    expect(s.products.firstWhere((p) => p.name == 'Indomie Goreng').qty, 20);
    expect(s.products.firstWhere((p) => p.name == 'Aqua 600ml').qty, 19);
    expect(teh.qty, 16);
  });

  test('confirming twice never double-posts', () async {
    final s = await seededStore();
    final doc = await s.createDocument(DocKind.dailySales);
    await s.extract(doc.id);
    doc.rows[2].productId = s.products.firstWhere((p) => p.name == 'Teh Pucuk').id;
    final results = await Future.wait([s.confirmDocument(doc.id), s.confirmDocument(doc.id)]);
    expect(results.where((r) => r.ok && !r.duplicate).length, 1);
    final again = await s.confirmDocument(doc.id);
    expect(again.duplicate, isTrue);
    expect(s.sales.length, 1);
    expect(s.summaryForDay(s.now).revenue, 75000);
  });

  test('cancelled draft leaves business records unchanged', () async {
    final s = await seededStore();
    final before = {for (final p in s.products) p.id: p.qty};
    final doc = await s.createDocument(DocKind.dailySales);
    await s.extract(doc.id);
    await s.cancelDocument(doc.id);
    expect(s.sales, isEmpty);
    for (final p in s.products) {
      expect(p.qty, before[p.id]);
    }
    expect((await s.confirmDocument(doc.id)).ok, isFalse);
  });

  test('second daily summary for same date is blocked', () async {
    final s = await seededStore();
    for (var i = 0; i < 2; i++) {
      final doc = await s.createDocument(DocKind.dailySales);
      await s.extract(doc.id);
      doc.rows[2].productId = s.products.firstWhere((p) => p.name == 'Teh Pucuk').id;
      final r = await s.confirmDocument(doc.id);
      expect(r.ok, i == 0, reason: r.message);
    }
    expect(s.sales.length, 1);
  });

  test('sale of product with unknown cost marks profit incomplete', () async {
    final s = AppStore(extractor: FastExtractor());
    await s.load();
    await s.signInDemo();
    await s.createBusiness(name: 'W', owner: 'O', city: 'C');
    await s.addProductManual(name: 'Gula', unit: 'kg', category: 'x', sellPrice: 16000, qty: 5, minQty: 1);
    final gula = s.products.single;
    final doc = await s.createDocument(DocKind.dailySales);
    doc.status = DocStatus.draft;
    doc.rows = [DraftRow(rawText: 'gula 2', name: 'Gula', productId: gula.id, qty: 2, unitPrice: 16000)];
    expect((await s.confirmDocument(doc.id)).ok, isTrue);
    final sum = s.summaryForDay(s.now);
    expect(sum.revenue, 32000);
    expect(sum.cogsComplete, isFalse);
    expect(sum.grossProfit, isNull);
    expect(sum.netProfit, isNull);
  });

  test('personal withdrawal does not reduce operating profit', () async {
    final s = await seededStore();
    await s.addExpenseManual(description: 'Listrik', category: 'Listrik & air', amount: 5000, type: ExpenseType.businessExpense);
    await s.addExpenseManual(description: 'Uang jajan', category: 'Pribadi', amount: 9000, type: ExpenseType.personalWithdrawal);
    final doc = await s.createDocument(DocKind.dailySales);
    await s.extract(doc.id);
    doc.rows[2].productId = s.products.firstWhere((p) => p.name == 'Teh Pucuk').id;
    await s.confirmDocument(doc.id);
    final sum = s.summaryForDay(s.now);
    expect(sum.opex, 5000);
    expect(sum.personal, 9000);
    expect(sum.netProfit, 15000);
  });

  test('mission XP is awarded once and only when verified', () async {
    final s = await seededStore();
    expect(await s.claimMission('daily_sales'), 0); // not verified yet
    final doc = await s.createDocument(DocKind.dailySales);
    await s.extract(doc.id);
    doc.rows[2].productId = s.products.firstWhere((p) => p.name == 'Teh Pucuk').id;
    await s.confirmDocument(doc.id);
    expect(await s.claimMission('daily_sales'), XpRules.dailyMission);
    expect(await s.claimMission('daily_sales'), 0);
  });

  test('sale exceeding stock is rejected', () async {
    final s = await seededStore();
    final doc = await s.createDocument(DocKind.dailySales);
    await s.extract(doc.id);
    doc.rows[2].productId = s.products.firstWhere((p) => p.name == 'Teh Pucuk').id;
    doc.rows[0].qty = 999;
    expect((await s.confirmDocument(doc.id)).ok, isFalse);
    expect(s.sales, isEmpty);
  });
}
