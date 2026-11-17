import 'dart:math';
import 'package:html_unescape/html_unescape.dart';

/// Thrown when OpenTDB data fails HTTP/API/schema validation.
class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

final _unescape = HtmlUnescape();

class Question {
  final String text;
  final String correct;

  /// Shuffled ONCE at parse time, never inside build().
  final List<String> choices;

  Question._(this.text, this.correct, this.choices);

  factory Question.fromJson(Map<String, dynamic> j, Random rng) {
    String need(String key) {
      final v = j[key];
      if (v is! String || v.trim().isEmpty) {
        throw ApiException('Question field "$key" is missing or empty');
      }
      return _unescape.convert(v).trim();
    }

    if (need('category') != 'General Knowledge') {
      throw ApiException('Question is not General Knowledge');
    }
    if (need('difficulty') != 'easy') throw ApiException('Question is not easy');
    if (need('type') != 'multiple') throw ApiException('Question is not multiple choice');

    final text = need('question');
    final correct = need('correct_answer');
    final wrongRaw = j['incorrect_answers'];
    if (wrongRaw is! List || wrongRaw.length != 3) {
      throw ApiException('Question needs exactly 3 incorrect answers');
    }
    final wrong = wrongRaw.map((e) {
      if (e is! String || e.trim().isEmpty) {
        throw ApiException('Empty incorrect answer');
      }
      return _unescape.convert(e).trim();
    }).toList();

    final all = [correct, ...wrong];
    if (all.toSet().length != 4 || all.any((c) => c.isEmpty)) {
      throw ApiException('Duplicate or empty answer choices');
    }
    all.shuffle(rng);
    return Question._(text, correct, List.unmodifiable(all));
  }
}

/// What the repository saves. Exactly these fields plus the server timestamp.
class AttemptData {
  static const schemaVersion = 1;
  static const variant = 'A';
  static const categoryId = 9;
  static const questionCount = 10;

  final int correctCount;
  AttemptData(this.correctCount);

  Map<String, Object?> fixedFields() => {
        'schemaVersion': schemaVersion,
        'variant': variant,
        'categoryId': categoryId,
        'questionCount': questionCount,
        'correctCount': correctCount,
      };
}

/// A document read back from the server.
class SavedAttempt {
  final String path;
  final Map<String, Object?> data;
  final DateTime submittedAt;
  SavedAttempt(this.path, this.data, this.submittedAt);
}
