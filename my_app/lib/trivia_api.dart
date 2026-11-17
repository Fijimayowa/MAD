import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'models.dart';

enum ApiFault { none, badJson, nonzeroCode, nineResults }

class TriviaApi {
  static final Uri classAUri = Uri.parse(
      'https://opentdb.com/api.php?amount=10&category=9&difficulty=easy&type=multiple');

  final http.Client _client;
  final Random _rng = Random();

  /// DEVELOPMENT ONLY: used for T03. Replaces the real response body.
  ApiFault fault = ApiFault.none;

  TriviaApi({http.Client? client}) : _client = client ?? http.Client();

  Future<List<Question>> fetch() async {
    int status = 200;
    String body;
    if (fault == ApiFault.badJson) {
      body = '{"response_code": 0, "results": [';
    } else if (fault == ApiFault.nonzeroCode) {
      body = '{"response_code": 5, "results": []}';
    } else {
      final res = await _client.get(classAUri).timeout(const Duration(seconds: 10));
      status = res.statusCode;
      body = res.body;
    }

    // Layer 1: HTTP success
    if (status != 200) throw ApiException('Server returned HTTP $status');

    // Layer 2: valid JSON
    final dynamic json;
    try {
      json = jsonDecode(body);
    } on FormatException {
      throw ApiException('Response was not valid JSON');
    }
    if (json is! Map<String, dynamic>) throw ApiException('Unexpected JSON shape');

    // Layer 3: API success
    if (json['response_code'] != 0) {
      throw ApiException('Trivia API error code ${json['response_code']}');
    }

    // Layer 4: schema validation
    var results = json['results'];
    if (fault == ApiFault.nineResults && results is List && results.length > 9) {
      results = results.sublist(0, 9);
    }
    if (results is! List || results.length != 10) {
      throw ApiException('Expected exactly 10 questions, got '
          '${results is List ? results.length : 'none'}');
    }
    return results
        .map((e) => Question.fromJson(Map<String, dynamic>.from(e as Map), _rng))
        .toList(growable: false);
  }
}
