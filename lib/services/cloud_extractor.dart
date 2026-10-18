import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models.dart';
import 'ai_extractor.dart';
import 'google_services.dart';

/// Calls the WarungPilot Cloud Run API (`backend/`), which runs Gemini on
/// Vertex AI. Google-connected builds send a Firebase ID token. The app key
/// remains available only for explicitly enabled legacy local development.
///
/// "Pakai contoh catatan" (no photo) still uses the offline demo output.
class CloudRunAiExtractor implements AiExtractor {
  final Uri endpoint;
  final String appKey;
  final Future<String?> Function()? tokenProvider;
  Map<String, dynamic> Function()? businessContext;
  final String clientId;
  final http.Client _http;
  final DemoAiExtractor _sample = DemoAiExtractor();
  final DateTime Function() clock;

  CloudRunAiExtractor({
    required String baseUrl,
    this.appKey = '',
    this.tokenProvider,
    this.clientId = 'app',
    http.Client? client,
    DateTime Function()? clock,
  }) : endpoint = Uri.parse(
         baseUrl.endsWith('/') ? '${baseUrl}v1/extract' : '$baseUrl/v1/extract',
       ),
       _http = client ?? http.Client(),
       clock = clock ?? DateTime.now;

  bool get simulateFailure => _sample.simulateFailure;
  set simulateFailure(bool v) => _sample.simulateFailure = v;

  @override
  Future<ExtractionResult> extract({
    required DocKind kind,
    Uint8List? image,
    required List<Product> catalog,
    required int attempt,
  }) async {
    if (image == null || _sample.simulateFailure) {
      return _sample.extract(
        kind: kind,
        image: image,
        catalog: catalog,
        attempt: attempt,
      );
    }
    final http.Response res;
    try {
      final token = await tokenProvider?.call();
      if (tokenProvider != null && (token == null || token.isEmpty)) {
        throw ExtractionException(
          'Sesi Google berakhir. Masuk kembali sebelum membaca foto.',
        );
      }
      res = await _http
          .post(
            endpoint,
            headers: {
              'content-type': 'application/json',
              if (token != null) 'authorization': 'Bearer $token',
              if (tokenProvider == null) 'x-app-key': appKey,
              'x-client-id': clientId,
            },
            body: jsonEncode({
              'kind': kind.name,
              'imageBase64': base64Encode(image),
              'mimeType': _mimeOf(image),
              'catalog': catalog
                  .where((p) => p.active)
                  .map((p) => p.name)
                  .take(500)
                  .toList(),
              'attempt': attempt.clamp(1, 10),
              if (businessContext != null) 'business': businessContext!(),
            }),
          )
          .timeout(const Duration(seconds: 45));
    } on TimeoutException {
      throw ExtractionException(
        'AI terlalu lama merespons. Periksa koneksi lalu proses ulang.',
      );
    } on http.ClientException {
      throw ExtractionException(
        'Tidak bisa terhubung ke server AI. Coba lagi.',
      );
    }

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw ExtractionException(
        'Respons server AI tidak valid (${res.statusCode}).',
      );
    }
    if (res.statusCode != 200) {
      throw ExtractionException(
        body['message'] as String? ??
            'AI gagal membaca foto (${res.statusCode}).',
      );
    }
    return parseResponse(kind, body, catalog);
  }

  /// Maps the API response to draft rows; product matching stays on-device
  /// so learned aliases (PRD §10.1) apply to real Gemini output too.
  ExtractionResult parseResponse(
    DocKind kind,
    Map<String, dynamic> body,
    List<Product> catalog,
  ) {
    final date = _parseDate(body['date'] as String?);
    if (kind == DocKind.expenseReceipt) {
      final e = body['expense'] as Map<String, dynamic>?;
      if (e == null) {
        throw ExtractionException('Struk tidak terbaca. Coba foto ulang.');
      }
      final type =
          ExpenseType.values.where((t) => t.name == e['type']).firstOrNull ??
          ExpenseType.businessExpense;
      return ExtractionResult(
        date: date,
        expense: DraftExpense(
          description: (e['description'] as String?) ?? '',
          category: (e['category'] as String?) ?? 'Lainnya',
          amount: (e['amount'] as num?)?.toDouble() ?? 0,
          vendor: e['vendor'] as String?,
          type: type,
          confidence: (e['confidence'] as num?)?.toDouble() ?? 0.5,
        ),
      );
    }
    final rows = <DraftRow>[
      for (final r
          in (body['rows'] as List? ?? const []).cast<Map<String, dynamic>>())
        draftRowFromReading(
          catalog,
          raw: (r['rawText'] as String?) ?? '',
          name: (r['name'] as String?) ?? '',
          qty: (r['qty'] as num?)?.toDouble() ?? 0,
          price: (r['unitPrice'] as num?)?.toDouble(),
          cost: (r['unitCost'] as num?)?.toDouble(),
          conf: (r['confidence'] as num?)?.toDouble() ?? 0.5,
        ),
    ];
    final readings = body['rows'] as List? ?? [];
    for (var i = 0; i < rows.length; i++) {
      rows[i].unit = (readings[i]['unit'] as String?)?.trim() ?? 'unit';
    }
    if (kind == DocKind.serviceIncome) {
      final readings = body['rows'] as List? ?? [];
      for (var i = 0; i < rows.length; i++) {
        rows[i].productId = null;
        rows[i].candidates = [];
        rows[i].unit =
            readings[i]['unit'] as String? ??
            businessContext?.call()['pricingUnit'] as String? ??
            'unit';
      }
    }
    return ExtractionResult(rows: rows, date: date);
  }

  /// Accept a written date only if it is plausible (not future, ≤ 60 days old).
  DateTime? _parseDate(String? s) {
    if (s == null) return null;
    final d = DateTime.tryParse(s);
    if (d == null) return null;
    final now = clock();
    final noon = DateTime(d.year, d.month, d.day, 12);
    if (noon.isAfter(DateTime(now.year, now.month, now.day, 23, 59))) {
      return null;
    }
    if (now.difference(noon).inDays > 60) return null;
    return noon;
  }

  static String _mimeOf(Uint8List b) {
    if (b.length >= 12 && String.fromCharCodes(b.sublist(4, 8)) == 'ftyp') {
      return GoogleServices.photoMime(b);
    }
    if (b.length > 3 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E) {
      return 'image/png';
    }
    if (b.length > 11 &&
        b[8] == 0x57 &&
        b[9] == 0x45 &&
        b[10] == 0x42 &&
        b[11] == 0x50) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }
}
