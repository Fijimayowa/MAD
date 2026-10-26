import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

abstract class TipService {
  bool get isMock;
  Future<String> fetchTip();
}

class HttpTipService implements TipService {
  HttpTipService(this.url);
  final String url; // instructor-supplied HTTPS URL

  @override
  bool get isMock => false;

  @override
  Future<String> fetchTip() async {
    final res = await http
        .post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          // add any instructor-specified access header here
          body: jsonEncode({'task': 'signup_tip', 'topic': 'password_help'}),
        )
        .timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) throw Exception('Bad status');
    final data = jsonDecode(res.body); // throws on invalid JSON
    final tip = data is Map ? data['tip'] : null;
    if (tip is! String || tip.trim().isEmpty) throw Exception('Empty tip');
    return tip.trim();
  }
}

class MockTipService implements TipService {
  @override
  bool get isMock => true;

  @override
  Future<String> fetchTip() async {
    await Future.delayed(const Duration(seconds: 1));
    return 'Try a passphrase: a few unrelated words are easier to remember than a short, complex password.';
  }
}
