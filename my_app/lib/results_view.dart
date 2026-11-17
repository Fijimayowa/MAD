import 'dart:convert';

import 'package:flutter/material.dart';
// For a real cloud write, add the package (flutter pub add http) and uncomment:
// import 'package:http/http.dart' as http;

enum SyncStatus { idle, syncing, synced, failed }

/// Shown after the last question is answered.
class ResultsView extends StatefulWidget {
  const ResultsView({
    super.key,
    required this.score,
    required this.total,
    this.playerName = 'Student',
  });

  final int score;
  final int total;
  final String playerName;

  @override
  State<ResultsView> createState() => _ResultsViewState();
}

class _ResultsViewState extends State<ResultsView> {
  SyncStatus _status = SyncStatus.idle;
  String? _error;

  // Flip to true ONLY if your instructor gave you an endpoint.
  static const bool _useRealBackend = false;
  // static const String _leaderboardUrl = 'PASTE_INSTRUCTOR_URL_HERE';

  /// The final score goes in the payload. Match your instructor's format
  /// if they supply one.
  Map<String, dynamic> _buildPayload() => {
        'player': widget.playerName,
        'score': widget.score,
        'total': widget.total,
        'submittedAt': DateTime.now().toUtc().toIso8601String(),
      };

  Future<void> _syncScoreToCloud() async {
    // Ignore taps while a sync is running or already finished.
    if (_status == SyncStatus.syncing || _status == SyncStatus.synced) return;

    setState(() {
      _status = SyncStatus.syncing;
      _error = null;
    });

    final payload = _buildPayload();

    try {
      if (_useRealBackend) {
        // REAL WRITE: only show success after the server confirms.
        // final response = await http.post(
        //   Uri.parse(_leaderboardUrl),
        //   headers: {'Content-Type': 'application/json'},
        //   body: jsonEncode(payload),
        // );
        // if (response.statusCode < 200 || response.statusCode >= 300) {
        //   throw Exception('Server returned ${response.statusCode}');
        // }
      } else {
        // SIMULATION: waits briefly, sends nothing anywhere.
        await Future.delayed(const Duration(seconds: 1));
        debugPrint('Simulated payload: ${jsonEncode(payload)}');
      }

      if (!mounted) return; // screen may have closed during the await
      setState(() => _status = SyncStatus.synced);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_useRealBackend
              ? 'Score saved to leaderboard'
              : 'Score synced (simulation, nothing was uploaded)'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = SyncStatus.failed;
        _error = 'Sync failed: $e';
      });
    }
  }

  String get _buttonLabel {
    switch (_status) {
      case SyncStatus.syncing:
        return 'Syncing...';
      case SyncStatus.synced:
        return _useRealBackend ? 'Synced' : 'Synced (simulation)';
      case SyncStatus.failed:
        return 'Retry sync';
      case SyncStatus.idle:
        return _useRealBackend
            ? 'Sync Score to Leaderboard'
            : 'Sync Score to Leaderboard (Simulation)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final canTap =
        _status == SyncStatus.idle || _status == SyncStatus.failed;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Final score: ${widget.score} / ${widget.total}',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: canTap ? _syncScoreToCloud : null,
            icon: _status == SyncStatus.syncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_upload),
            label: Text(_buttonLabel),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
    );
  }
}
