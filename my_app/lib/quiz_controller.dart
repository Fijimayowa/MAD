import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'attempt_repository.dart';
import 'models.dart';
import 'trivia_api.dart';

/// signedOut and authError live in the sign-in screen / AuthGate.
enum Phase {
  idle,
  loading,
  playing,
  readyToSubmit,
  submitting,
  verifying,
  cloudVerified,
  requestError,
  saveUnknown,
  permissionDenied,
  saveFailed, // unavailable, resource-exhausted, unauthenticated, collision, other
  verificationUnavailable,
}

class QuizController extends ChangeNotifier {
  QuizController({required this.api, required this.repo, required this.uid});

  final TriviaApi api;
  final AttemptRepository repo;
  final String uid; // UID that owns this controller; stale responses are dropped

  Phase phase = Phase.idle;
  String message = '';
  List<Question> questions = const [];
  List<int?> selections = List.filled(10, null);
  int index = 0;
  String? roundId;
  SavedAttempt? verified;
  DateTime? _lastRequest;
  bool _busy = false;
  bool _disposed = false;

  bool get answered => selections[index] != null;
  int get correctCount {
    var n = 0;
    for (var i = 0; i < questions.length; i++) {
      final s = selections[i];
      if (s != null && questions[i].choices[s] == questions[i].correct) n++;
    }
    return n;
  }

  /// A submission whose outcome is not settled: block replay and sign-out.
  bool get unresolved =>
      phase == Phase.submitting ||
      phase == Phase.verifying ||
      phase == Phase.saveUnknown ||
      phase == Phase.verificationUnavailable ||
      phase == Phase.saveFailed;

  bool get canReplay => !unresolved && phase != Phase.loading;

  bool _isCurrent(String forUid, String? forRound) =>
      !_disposed &&
      forUid == uid &&
      FirebaseAuth.instance.currentUser?.uid == forUid &&
      forRound == roundId;

  void _set(Phase p, [String m = '']) {
    phase = p;
    message = m;
    if (!_disposed) notifyListeners();
  }

  // ---------- Load ----------

  Future<void> startRound() async {
    if (_busy || !canReplay && phase != Phase.idle) return;
    final now = DateTime.now();
    if (_lastRequest != null) {
      final wait = 5 - now.difference(_lastRequest!).inSeconds;
      if (wait > 0) {
        _set(Phase.requestError, 'Please wait $wait more seconds (trivia service rate limit), then retry.');
        return;
      }
    }
    _busy = true;
    _lastRequest = now;
    selections = List.filled(10, null);
    index = 0;
    verified = null;
    questions = const [];
    roundId = repo.newRoundId(uid); // fresh ID per round, kept across retries
    final myRound = roundId;
    _set(Phase.loading, 'Loading questions…');
    try {
      final q = await api.fetch();
      if (!_isCurrent(uid, myRound)) return;
      questions = q;
      _set(Phase.playing);
    } catch (e) {
      if (!_isCurrent(uid, myRound)) return;
      _set(Phase.requestError, 'Could not load a valid round: $e');
    } finally {
      _busy = false;
    }
  }

  // ---------- Play ----------

  void select(int choice) {
    if (phase != Phase.playing || answered) return; // double taps do nothing
    selections[index] = choice;
    notifyListeners();
  }

  void next() {
    if (phase != Phase.playing || !answered) return;
    if (index == questions.length - 1) {
      _set(Phase.readyToSubmit);
    } else {
      index++;
      notifyListeners();
    }
  }

  // ---------- Submit / recover ----------

  /// Safe to call again for the same roundId: the transaction is create-once.
  Future<void> submit() async {
    if (_busy) return;
    if (phase != Phase.readyToSubmit &&
        phase != Phase.saveFailed &&
        phase != Phase.saveUnknown) {
      return;
    }
    final myUid = uid, myRound = roundId, score = correctCount;
    if (myRound == null) return;
    _busy = true;
    _set(Phase.submitting, 'Saving to the cloud…');
    try {
      await repo.createOnce(uid: myUid, roundId: myRound, correctCount: score);
    } on InjectedAckLost catch (e) {
      if (!_isCurrent(myUid, myRound)) return;
      _busy = false;
      _set(Phase.saveUnknown,
          '$e The save may or may not have happened. Tap "Check server" to find out.');
      return;
    } on CollisionException catch (e) {
      if (!_isCurrent(myUid, myRound)) return;
      _set(Phase.saveFailed, e.toString());
      _busy = false;
      return;
    } on FirebaseException catch (e) {
      if (!_isCurrent(myUid, myRound)) return;
      _busy = false;
      _mapFirebaseError(e);
      return;
    } catch (e) {
      if (!_isCurrent(myUid, myRound)) return;
      _busy = false;
      _set(Phase.saveUnknown, 'Unexpected problem ($e). Outcome unknown. Check server.');
      return;
    }
    _busy = false;
    await _verify(myUid, myRound, score);
  }

  /// From saveUnknown or verificationUnavailable: ask the server what really happened.
  Future<void> checkServer() async {
    if (_busy || roundId == null) return;
    if (phase != Phase.saveUnknown && phase != Phase.verificationUnavailable) return;
    await _verify(uid, roundId!, correctCount, fromRecovery: true);
  }

  Future<void> _verify(String myUid, String myRound, int score,
      {bool fromRecovery = false}) async {
    _busy = true;
    _set(Phase.verifying, 'Verifying with the server…');
    try {
      final saved = await repo.readFromServer(
          uid: myUid, roundId: myRound, expectCorrectCount: score);
      if (!_isCurrent(myUid, myRound)) return;
      verified = saved;
      _set(Phase.cloudVerified, 'Cloud verified');
    } on NotFoundException {
      if (!_isCurrent(myUid, myRound)) return;
      // Server says nothing was committed: safe to retry with the same ID.
      _set(Phase.saveFailed, 'The server has no record of this round. Safe to retry with the same ID.');
    } on FirebaseException catch (e) {
      if (!_isCurrent(myUid, myRound)) return;
      _set(Phase.verificationUnavailable,
          'Saved, but verification is unavailable (${e.code}). Try again.');
    } on VerificationException catch (e) {
      if (!_isCurrent(myUid, myRound)) return;
      _set(Phase.verificationUnavailable, e.message);
    } finally {
      _busy = false;
    }
  }

  void _mapFirebaseError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        _set(Phase.permissionDenied,
            'Permission denied by the security rules. Your score was not saved.');
        break;
      case 'unauthenticated':
        _set(Phase.saveFailed, 'You are signed out. Sign in again, then retry.');
        break;
      case 'unavailable':
        _set(Phase.saveFailed,
            'Cloud unavailable (offline?). Nothing confirmed. Reconnect, then retry with the same round.');
        break;
      case 'resource-exhausted':
        _set(Phase.saveFailed,
            'Cloud quota exhausted. Do not keep retrying; try later or contact the instructor.');
        break;
      case 'deadline-exceeded':
      case 'aborted':
        _set(Phase.saveUnknown,
            'The save timed out (${e.code}). It may have committed. Tap "Check server".');
        break;
      default:
        _set(Phase.saveFailed, 'Save failed (${e.code}).');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Read a saved attempt by ID, from the server, for T07 (works after restart).
Future<SavedAttempt> retrieveAttempt(
    AttemptRepository repo, String uid, String roundId) {
  return repo.readFromServer(uid: uid, roundId: roundId.trim());
}
