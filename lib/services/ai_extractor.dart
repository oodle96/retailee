import 'dart:typed_data';

import '../models.dart';

/// Result of an AI extraction call.
class ExtractionResult {
  final List<DraftRow> rows;
  final DraftExpense? expense;
  final DateTime? date;
  const ExtractionResult({this.rows = const [], this.expense, this.date});
}

class ExtractionException implements Exception {
  final String message;
  ExtractionException(this.message);
  @override
  String toString() => message;
}

/// Extraction backend contract. The production implementation calls Cloud Run
/// (which holds the Gemini key) — never Gemini directly from the app.
abstract class AiExtractor {
  Future<ExtractionResult> extract({
    required DocKind kind,
    Uint8List? image,
    required List<Product> catalog,
    required int attempt,
  });
}

/// Demo extractor: returns realistic, schema-shaped output for the PRD demo
/// dataset so the full flow works without an API key.
class DemoAiExtractor implements AiExtractor {
  /// Set true to exercise the failure / recovery UI.
  bool simulateFailure = false;

  @override
  Future<ExtractionResult> extract({
    required DocKind kind,
    Uint8List? image,
    required List<Product> catalog,
    required int attempt,
  }) async {
    if (image != null && !simulateFailure) {
      throw ExtractionException(
        'Pembacaan foto belum terhubung ke Gemini. Hubungkan layanan Google atau isi manual. Contoh catatan tersedia untuk demo.',
      );
    }
    await Future.delayed(const Duration(milliseconds: 2400));
    if (simulateFailure) {
      simulateFailure = false;
      throw ExtractionException(
        'Foto kurang jelas atau koneksi terputus. Coba foto ulang dengan cahaya cukup.',
      );
    }
    final retry = attempt > 1;
    switch (kind) {
      case DocKind.serviceIncome:
        throw ExtractionException(
          'Gunakan foto layanan selesai atau isi manual. Contoh retail tidak dipakai untuk jasa.',
        );
      case DocKind.openingStock:
        return ExtractionResult(
          rows: [
            _row(
              catalog,
              'Indomie goreng 30 bks modal 2600 jual 3500',
              'Indomie Goreng',
              qty: 30,
              cost: 2600,
              price: 3500,
              conf: 0.95,
            ),
            _row(
              catalog,
              'Aqua 600 24 btl modal 3rb jual 4rb',
              'Aqua 600ml',
              qty: 24,
              cost: 3000,
              price: 4000,
              conf: 0.92,
            ),
            _row(
              catalog,
              'Teh pucuk 20 modal 3500 jual 5rb',
              'Teh Pucuk',
              qty: 20,
              cost: 3500,
              price: 5000,
              conf: 0.9,
            ),
            _row(
              catalog,
              'Gula 1kg 8 jual 16rb (modal ?)',
              'Gula Pasir 1kg',
              qty: 8,
              cost: null,
              price: 16000,
              conf: retry ? 0.8 : 0.58,
            ),
          ],
        );
      case DocKind.dailySales:
        return ExtractionResult(
          rows: [
            _row(
              catalog,
              'indomie 10 x 3500',
              'Indomie Goreng',
              qty: 10,
              price: 3500,
              conf: 0.94,
            ),
            _row(
              catalog,
              'aqua 5 @4rb',
              'Aqua 600ml',
              qty: 5,
              price: 4000,
              conf: 0.9,
            ),
            _row(
              catalog,
              'teh pcuk 4 x 5000',
              retry ? 'Teh Pucuk' : 'Teh pcuk',
              qty: 4,
              price: 5000,
              conf: retry ? 0.88 : 0.62,
            ),
          ],
        );
      case DocKind.expenseReceipt:
        return ExtractionResult(
          expense: DraftExpense(
            description: 'Token listrik PLN',
            category: 'Listrik & air',
            amount: 50000,
            vendor: 'PLN',
            type: ExpenseType.businessExpense,
            confidence: 0.91,
          ),
        );
    }
  }

  DraftRow _row(
    List<Product> catalog,
    String raw,
    String name, {
    required double qty,
    double? cost,
    double? price,
    required double conf,
  }) => draftRowFromReading(
    catalog,
    raw: raw,
    name: name,
    qty: qty,
    cost: cost,
    price: price,
    conf: conf,
  );
}

/// Turns one line read by the AI into an editable draft row, matching it
/// against the catalog. Used by both the demo and the Cloud Run extractor.
DraftRow draftRowFromReading(
  List<Product> catalog, {
  required String raw,
  required String name,
  required double qty,
  double? cost,
  double? price,
  required double conf,
}) {
  final candidates = matchProducts(name, catalog);
  final best = candidates.isNotEmpty ? candidates.first : null;
  // A spelling the owner confirmed before is trusted (PRD §10.1 aliases).
  final learned = best != null && best.viaAlias;
  return DraftRow(
    rawText: raw,
    name: name,
    productId: best != null && best.score >= 0.6 ? best.product.id : null,
    qty: qty,
    unitCost: cost,
    unitPrice: price,
    confidence: learned ? (conf > 0.96 ? conf : 0.96) : conf,
    candidates: candidates.take(3).map((c) => c.product.id).toList(),
    learned: learned,
  );
}

class ProductMatch {
  final Product product;
  final double score;
  final bool viaAlias; // exact hit on an owner-confirmed alias
  ProductMatch(this.product, this.score, {this.viaAlias = false});
}

/// Lowercase, strip punctuation, collapse spaces.
String normalizeText(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
    .replaceAll(RegExp(r' +'), ' ')
    .trim();

String _norm(String s) => normalizeText(s);

Set<String> _bigrams(String s) {
  final t = _norm(s).replaceAll(' ', '');
  final out = <String>{};
  for (var i = 0; i < t.length - 1; i++) {
    out.add(t.substring(i, i + 2));
  }
  return out;
}

double similarity(String a, String b) {
  final x = _bigrams(a), y = _bigrams(b);
  if (x.isEmpty || y.isEmpty) return 0;
  final inter = x.intersection(y).length;
  return 2 * inter / (x.length + y.length);
}

/// Fuzzy product matcher (name + aliases), best first.
List<ProductMatch> matchProducts(String name, List<Product> catalog) {
  final out = <ProductMatch>[];
  for (final p in catalog.where((p) => p.active)) {
    if (p.aliases.any((a) => _norm(a) == _norm(name))) {
      out.add(ProductMatch(p, 1, viaAlias: true));
      continue;
    }
    var best = similarity(name, p.name);
    for (final a in p.aliases) {
      final s = similarity(name, a);
      if (s > best) best = s;
    }
    // first-word boost: handwritten notes often abbreviate ("aqua" vs "Aqua 600ml")
    final first = _norm(name).split(' ').first;
    if (first.length >= 3 && _norm(p.name).startsWith(first)) {
      best = (best + 0.35).clamp(0, 1);
    }
    if (best > 0.25) out.add(ProductMatch(p, best));
  }
  out.sort((a, b) => b.score.compareTo(a.score));
  return out;
}
