import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id, text, authorUid, authorName;
  final DateTime? createdAt, editedAt; // createdAt is null briefly until the server stamps it
  const Message({
    required this.id,
    required this.text,
    required this.authorUid,
    required this.authorName,
    this.createdAt,
    this.editedAt,
  });

  factory Message.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    return Message(
      id: d.id,
      text: (m['text'] ?? '') as String,
      authorUid: (m['authorUid'] ?? '') as String,
      authorName: (m['authorName'] ?? 'Unknown') as String,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      editedAt: (m['editedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Owns every Firestore call. Authorization is enforced by firestore.rules,
/// not by this class or the UI.
class BoardService {
  BoardService._();
  static final BoardService instance = BoardService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _messages => _db.collection('messages');

  // ---- users/{uid}: private record, written once at registration ----
  Future<void> saveUserRecord({
    required String uid,
    required String firstName,
    required String lastName,
    required String role,
  }) {
    return _db.collection('users').doc(uid).set({
      'uid': uid,
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'role': role, // descriptive only; never used for access decisions
      'registrationDateTime': FieldValue.serverTimestamp(),
    });
  }

  // ---- messages/{msgId}: public board ----

  /// Live read: re-emits on every change from any device. Oldest to newest.
  Stream<List<Message>> messagesStream() {
    return _messages
        .orderBy('createdAt')
        .snapshots()
        .map((s) => s.docs.map(Message.fromDoc).toList());
  }

  /// Generate the id once per compose attempt. Retries / offline replays
  /// reuse the same id, so the write is idempotent (no duplicates).
  String newMessageId() => _messages.doc().id;

  Future<void> createMessage({
    required String id,
    required String text,
    required String authorUid,
    required String authorName,
  }) {
    return _messages.doc(id).set({
      'text': text.trim(),
      'authorUid': authorUid,
      'authorName': authorName,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateMessage(String id, String text) {
    return _messages.doc(id).update({
      'text': text.trim(),
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMessage(String id) => _messages.doc(id).delete();

  static String friendlyError(Object e) {
    if (e is FirebaseException) {
      switch (e.code) {
        case 'permission-denied':
          return 'Not allowed: you can only change your own messages.';
        case 'unavailable':
          return 'You appear to be offline. Your change will sync when you reconnect.';
        case 'not-found':
          return 'That message no longer exists.';
      }
    }
    return 'Something went wrong. Please try again.';
  }
}
