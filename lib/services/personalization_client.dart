import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class BusinessAdvice {
  final String intro, model, generatedAt;
  final List<Map<String, dynamic>> recommendations;
  BusinessAdvice(
    this.intro,
    this.model,
    this.generatedAt,
    this.recommendations,
  );
  factory BusinessAdvice.fromJson(Map<String, dynamic> j) => BusinessAdvice(
    j['intro'],
    j['model'],
    j['generatedAt'],
    (j['recommendations'] as List)
        .map((r) => Map<String, dynamic>.from(r))
        .toList(),
  );
  Map<String, dynamic> toJson() => {
    'intro': intro,
    'model': model,
    'generatedAt': generatedAt,
    'recommendations': recommendations,
  };
}

class PersonalizationClient {
  final Uri endpoint;
  final Future<String?> Function()? tokenProvider;
  final String appKey;
  PersonalizationClient(String baseUrl, {this.tokenProvider, this.appKey = ''})
    : endpoint = Uri.parse(
        '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/v1/personalize',
      );
  Future<BusinessAdvice> generate(Map<String, dynamic> context) async {
    final token = await tokenProvider?.call();
    if (tokenProvider != null && (token == null || token.isEmpty)) {
      throw StateError('Masuk kembali dengan Google.');
    }
    final res = await http
        .post(
          endpoint,
          headers: {
            'content-type': 'application/json',
            if (token != null) 'authorization': 'Bearer $token',
            if (tokenProvider == null) 'x-app-key': appKey,
          },
          body: jsonEncode(context),
        )
        .timeout(const Duration(seconds: 55));
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw StateError(
        data['message'] as String? ?? 'Saran Gemini belum tersedia.',
      );
    }
    final advice = BusinessAdvice.fromJson(data);
    final ids = (context['facts'] as List).map((f) => f['id']).toSet();
    if (advice.recommendations.any(
      (r) =>
          (r['factIds'] as List).isEmpty ||
          (r['factIds'] as List).any((id) => !ids.contains(id)),
    )) {
      throw StateError('Bukti saran tidak sesuai dengan catatan usaha.');
    }
    return advice;
  }

  Future<Map<String, dynamic>> understand(
    Map<String, dynamic> business,
    List<Map<String, String>> answers,
  ) async {
    final token = await tokenProvider?.call();
    if (tokenProvider != null && (token == null || token.isEmpty)) {
      throw StateError('Masuk kembali dengan Google.');
    }
    final res = await http
        .post(
          endpoint.replace(path: '/v1/business-understanding'),
          headers: {
            'content-type': 'application/json',
            if (token != null) 'authorization': 'Bearer $token',
            if (tokenProvider == null) 'x-app-key': appKey,
          },
          body: jsonEncode({'business': business, 'answers': answers}),
        )
        .timeout(const Duration(seconds: 55));
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw StateError(
        data['message'] ?? 'Gemini belum dapat memahami usaha. Coba lagi.',
      );
    }
    if (!['goods', 'services', 'mixed'].contains(data['mode']) ||
        data['questions'] is! List ||
        data['summary'] is! String) {
      throw StateError('Respons Gemini tidak valid.');
    }
    final activities = data['activities'];
    if (activities is! List ||
        activities.isEmpty ||
        activities.length > 3 ||
        activities.any(
          (a) => !['resale', 'services', 'production'].contains(a),
        )) {
      throw StateError('Respons Gemini tidak valid.');
    }
    data['activities'] = activities
        .map((a) => a == 'production' ? 'resale' : a)
        .toSet()
        .toList();
    return data;
  }
}
