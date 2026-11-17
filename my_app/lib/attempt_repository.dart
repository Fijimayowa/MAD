import 'package:cloud_firestore/cloud_firestore.dart';
import 'models.dart';

class CollisionException implements Exception {
  @override
  String toString() =>
      'Round ID collision: a different attempt already exists under this ID. Original preserved.';
}

class NotFoundException implements Exception {
  @override
  String toString() => 'No attempt found on the server for this ID.';
}

class VerificationException implements Exception {
  final String message;
  VerificationException(this.message);
  @override
  String toString() => message;
}

/// DEVELOPMENT ONLY marker: the commit really happened, the acknowledgement is hidden.
class InjectedAckLost implements Exception {
  @override
  String toString() => '[INJECTED FAULT] Acknowledgement hidden after a real commit.';
}

class AttemptRepository {
  AttemptRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  /// DEVELOPMENT ONLY fault injection (T09, T12).
  bool injectLostAck = false;
  String? injectErrorCode; // e.g. 'unavailable', 'resource-exhausted'

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('attempts');

  DocumentReference<Map<String, dynamic>> ref(String uid, String roundId) =>
      _col(uid).doc(roundId);

  /// Reserves no server document; just generates an ID.
  String newRoundId(String uid) => _col(uid).doc().id;

  /// Create once. Reuses a matching existing doc, rejects a mismatch, never overwrites.
  Future<void> createOnce({
    required String uid,
    required String roundId,
    required int correctCount,
  }) async {
    if (injectErrorCode != null) {
      throw FirebaseException(plugin: 'cloud_firestore', code: injectErrorCode);
    }
    final docRef = ref(uid, roundId);
    final fixed = AttemptData(correctCount).fixedFields();

    // The callback only reads and writes; no UI, no random IDs, no other network calls.
    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (snap.exists) {
        final d = snap.data()!;
        final same = fixed.entries.every((e) => d[e.key] == e.value);
        if (!same) throw CollisionException();
        return; // matching retry: reuse
      }
      tx.set(docRef, {...fixed, 'submittedAt': FieldValue.serverTimestamp()});
    });

    if (injectLostAck) throw InjectedAckLost();
  }

  /// Server-only read. Cache hits do not count as proof.
  Future<SavedAttempt> readFromServer({
    required String uid,
    required String roundId,
    int? expectCorrectCount,
  }) async {
    final snap =
        await ref(uid, roundId).get(const GetOptions(source: Source.server));
    if (!snap.exists) throw NotFoundException();
    if (snap.metadata.isFromCache) {
      throw VerificationException('Result came from cache, not the server.');
    }
    if (snap.metadata.hasPendingWrites) {
      throw VerificationException('Document still has pending writes.');
    }
    final d = snap.data()!;
    final ts = d['submittedAt'];
    if (ts is! Timestamp) {
      throw VerificationException('Server timestamp not resolved yet.');
    }
    final expected = {
      'schemaVersion': AttemptData.schemaVersion,
      'variant': AttemptData.variant,
      'categoryId': AttemptData.categoryId,
      'questionCount': AttemptData.questionCount,
    };
    for (final e in expected.entries) {
      if (d[e.key] != e.value) {
        throw VerificationException('Field ${e.key} does not match the contract.');
      }
    }
    final cc = d['correctCount'];
    if (cc is! int || cc < 0 || cc > 10) {
      throw VerificationException('correctCount is invalid.');
    }
    if (expectCorrectCount != null && cc != expectCorrectCount) {
      throw VerificationException('correctCount differs from this round.');
    }
    if (d.length != 6) throw VerificationException('Unexpected extra fields.');
    return SavedAttempt(snap.reference.path, Map<String, Object?>.from(d), ts.toDate());
  }
}
