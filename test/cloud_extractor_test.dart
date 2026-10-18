import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warungpilot/models.dart';
import 'package:warungpilot/services/ai_extractor.dart';
import 'package:warungpilot/services/cloud_extractor.dart';

final catalog = [
  Product(id: 'p1', name: 'Indomie Goreng', sellPrice: 3500, avgCost: 2600, qty: 30),
  Product(id: 'p2', name: 'Aqua 600ml', sellPrice: 4000, avgCost: 3000, qty: 24),
  Product(id: 'p3', name: 'Teh Pucuk', sellPrice: 5000, avgCost: 3500, qty: 20, aliases: ['teh pcuk']),
];
final photo = Uint8List.fromList(List.filled(300, 0xFF));

CloudRunAiExtractor withServer(http.Response Function(http.Request) handler, {List<http.Request>? seen}) =>
    CloudRunAiExtractor(
      baseUrl: 'https://api.example.run.app',
      appKey: 'k',
      clock: () => DateTime(2026, 10, 16, 15),
      client: MockClient((req) async {
        seen?.add(req);
        return handler(req);
      }),
    );

void main() {
  test('sends kind, image, catalog and app key; matches rows on device', () async {
    final seen = <http.Request>[];
    final ex = withServer(
      (_) => http.Response(
          jsonEncode({
            'kind': 'dailySales',
            'date': '2026-10-16',
            'rows': [
              {'rawText': 'aqua 5 @4rb', 'name': 'aqua', 'qty': 5, 'unitPrice': 4000, 'confidence': 0.9},
              {'rawText': 'teh pcuk 4 x 5000', 'name': 'teh pcuk', 'qty': 4, 'unitPrice': 5000, 'confidence': 0.6},
            ],
          }),
          200),
      seen: seen,
    );
    final res = await ex.extract(kind: DocKind.dailySales, image: photo, catalog: catalog, attempt: 1);
    final body = jsonDecode(seen.single.body) as Map<String, dynamic>;
    expect(seen.single.url.path, '/v1/extract');
    expect(seen.single.headers['x-app-key'], 'k');
    expect(body['kind'], 'dailySales');
    expect(body['catalog'], contains('Teh Pucuk'));
    expect(res.date, DateTime(2026, 10, 16, 12));
    expect(res.rows[0].productId, 'p2');
    // Learned alias makes a shaky Gemini read confident and pre-matched.
    expect(res.rows[1].productId, 'p3');
    expect(res.rows[1].learned, isTrue);
    expect(res.rows[1].unclear, isFalse);
  });

  test('ignores implausible dates', () async {
    final ex = withServer((_) => http.Response(
        jsonEncode({'date': '2027-01-01', 'rows': [{'rawText': 'x', 'name': 'Aqua', 'qty': 1, 'unitPrice': 4000, 'confidence': 1}]}),
        200));
    final res = await ex.extract(kind: DocKind.dailySales, image: photo, catalog: catalog, attempt: 1);
    expect(res.date, isNull);
  });

  test('server error message surfaces for the recovery screen', () async {
    final ex = withServer((_) => http.Response(jsonEncode({'message': 'AI belum bisa membaca foto ini.'}), 502));
    expect(
      () => ex.extract(kind: DocKind.dailySales, image: photo, catalog: catalog, attempt: 1),
      throwsA(isA<ExtractionException>().having((e) => e.message, 'message', contains('belum bisa'))),
    );
  });

  test('sample note (no photo) uses demo output without a network call', () async {
    final seen = <http.Request>[];
    final ex = withServer((_) => http.Response('{}', 500), seen: seen);
    final res = await ex.extract(kind: DocKind.expenseReceipt, image: null, catalog: catalog, attempt: 1);
    expect(seen, isEmpty);
    expect(res.expense?.amount, 50000);
  });

  test('maps expense type and amount', () async {
    final ex = withServer((_) => http.Response(
        jsonEncode({
          'expense': {'description': 'Bensin', 'amount': 25000, 'vendor': null, 'category': 'Transportasi', 'type': 'businessExpense', 'confidence': 0.8},
        }),
        200));
    final res = await ex.extract(kind: DocKind.expenseReceipt, image: photo, catalog: catalog, attempt: 1);
    expect(res.expense!.amount, 25000);
    expect(res.expense!.type, ExpenseType.businessExpense);
    expect(res.expense!.category, 'Transportasi');
  });
}
