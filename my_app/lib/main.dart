// In-Class 15: Trivia Showdown
// Setup: flutter pub add http
// Replace lib/main.dart with this file.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const TriviaApp());

class TriviaApp extends StatelessWidget {
  const TriviaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trivia Showdown',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: const TriviaScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class Question {
  final String questionText;
  final String correctAnswer;
  final List<String> options;

  Question({
    required this.questionText,
    required this.correctAnswer,
    required this.options,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    final correct = cleanText(json['correct_answer'] as String);
    final incorrect = (json['incorrect_answers'] as List<dynamic>)
        .map((e) => cleanText(e as String))
        .toList();
    final options = [...incorrect, correct]..shuffle(Random());
    return Question(
      questionText: cleanText(json['question'] as String),
      correctAnswer: correct,
      options: options,
    );
  }
}

/// Decodes the HTML entities the API commonly returns.
String cleanText(String input) {
  var text = input
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&eacute;', 'é')
      .replaceAll('&ouml;', 'ö')
      .replaceAll('&uuml;', 'ü')
      .replaceAll('&ntilde;', 'ñ')
      .replaceAll('&hellip;', '…')
      .replaceAll('&rsquo;', '’')
      .replaceAll('&ldquo;', '“')
      .replaceAll('&rdquo;', '”');

  // Numeric entities like &#8211;
  text = text.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
    final code = int.tryParse(m.group(1)!);
    return code == null ? m.group(0)! : String.fromCharCode(code);
  });

  // &amp; last so we don't double-decode.
  return text.replaceAll('&amp;', '&');
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

enum LoadState { loading, ready, error }

class TriviaScreen extends StatefulWidget {
  const TriviaScreen({super.key});

  @override
  State<TriviaScreen> createState() => _TriviaScreenState();
}

class _TriviaScreenState extends State<TriviaScreen> {
  static const _url =
      'https://opentdb.com/api.php?amount=5&category=9&difficulty=easy&type=multiple';

  LoadState _state = LoadState.loading;
  String _errorMessage = '';

  List<Question> _questions = [];
  int _index = 0;
  int _score = 0;
  String? _selected; // null until the player answers
  bool _finished = false;

  bool _syncing = false;
  bool _synced = false;

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  // ----- Network ----------------------------------------------------------

  Future<void> _fetchQuestions() async {
    setState(() {
      _state = LoadState.loading;
      _questions = [];
      _index = 0;
      _score = 0;
      _selected = null;
      _finished = false;
      _syncing = false;
      _synced = false;
    });

    try {
      final response = await http
          .get(Uri.parse(_url))
          .timeout(const Duration(seconds: 10));

      // 1) Transport-level check
      if (response.statusCode != 200) {
        throw Exception('Server returned HTTP ${response.statusCode}.');
      }

      // 2) API-level check
      final data = json.decode(response.body) as Map<String, dynamic>;
      final code = data['response_code'];
      if (code != 0) {
        throw Exception(_apiCodeMessage(code));
      }

      final results = data['results'] as List<dynamic>;
      if (results.isEmpty) {
        throw Exception('No questions were returned.');
      }

      final questions = results
          .map((e) => Question.fromJson(e as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        _questions = questions;
        _state = LoadState.ready;
      });
    } on TimeoutException {
      _showError('The request timed out. Check your connection and try again.');
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  String _apiCodeMessage(dynamic code) {
    switch (code) {
      case 1:
        return 'Not enough questions available for this request.';
      case 2:
        return 'Invalid request parameter.';
      case 5:
        return 'Too many requests. Wait a few seconds and try again.';
      default:
        return 'Trivia API did not return questions (code $code).';
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
      _state = LoadState.error;
    });
  }

  // ----- Round logic ------------------------------------------------------

  void _selectAnswer(String answer) {
    if (_selected != null) return; // one answer per question
    setState(() {
      _selected = answer;
      if (answer == _questions[_index].correctAnswer) {
        _score++; // only counted on the first tap
      }
    });
  }

  void _next() {
    setState(() {
      if (_index < _questions.length - 1) {
        _index++;
        _selected = null;
      } else {
        _finished = true;
      }
    });
  }

  // ----- Simulated sync ---------------------------------------------------
  // This does NOT write to a backend. It only waits briefly and updates UI.

  Future<void> _syncScoreToCloud() async {
    setState(() => _syncing = true);

    // Payload a real POST would send:
    final payload = json.encode({
      'score': _score,
      'total': _questions.length,
      'timestamp': DateTime.now().toIso8601String(),
    });
    debugPrint('Simulated payload (not sent): $payload');

    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;
    setState(() {
      _syncing = false;
      _synced = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Simulation only: score marked as synced. '
            'No data was sent to a server.'),
      ),
    );
  }

  // ----- UI ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trivia Showdown')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: switch (_state) {
            LoadState.loading => const Center(
                child: CircularProgressIndicator(),
              ),
            LoadState.error => _buildError(),
            LoadState.ready => _finished ? _buildResult() : _buildQuestion(),
          },
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 56, color: Colors.red),
          const SizedBox(height: 12),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _fetchQuestions,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion() {
    final q = _questions[_index];
    final answered = _selected != null;
    final isLast = _index == _questions.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Question ${_index + 1} of ${_questions.length}',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: (_index + (answered ? 1 : 0)) / _questions.length,
        ),
        const SizedBox(height: 24),
        Text(
          q.questionText,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 24),
        Expanded(
          child: ListView(
            children: q.options.map((option) {
              Color? color;
              if (answered) {
                if (option == q.correctAnswer) {
                  color = Colors.green;
                } else if (option == _selected) {
                  color = Colors.red;
                }
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    disabledBackgroundColor: color,
                    foregroundColor: Colors.white,
                    disabledForegroundColor:
                        color == null ? null : Colors.white,
                    padding: const EdgeInsets.all(16),
                  ),
                  onPressed: answered ? null : () => _selectAnswer(option),
                  child: Text(option, textAlign: TextAlign.center),
                ),
              );
            }).toList(),
          ),
        ),
        Text('Score: $_score', textAlign: TextAlign.center),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: answered ? _next : null,
          child: Text(isLast ? 'Finish' : 'Next'),
        ),
      ],
    );
  }

  Widget _buildResult() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events, size: 64, color: Colors.amber),
          const SizedBox(height: 12),
          Text(
            'Final score: $_score / ${_questions.length}',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: (_syncing || _synced) ? null : _syncScoreToCloud,
            icon: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_synced ? Icons.check : Icons.cloud_upload),
            label: Text(_synced
                ? 'Synced (simulation)'
                : 'Sync Score to Leaderboard (Simulation)'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _fetchQuestions,
            icon: const Icon(Icons.replay),
            label: const Text('Play Again'),
          ),
        ],
      ),
    );
  }
}
