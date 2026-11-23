import 'package:firebase_auth/firebase_auth.dart';

/// Owns every FirebaseAuth call. Authentication = proving WHO the user is.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  FirebaseAuth get _auth => FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Creates the account and returns the new user. The Firestore user record
  /// is written separately by BoardService.saveUserRecord.
  Future<User> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    final user = cred.user!;
    await user.updateDisplayName('$firstName $lastName'.trim());
    return user;
  }

  Future<User> signIn({required String email, required String password}) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    return cred.user!;
  }

  Future<void> signOut() => _auth.signOut();

  /// Translates Firebase Auth errors into safe, helpful messages.
  static String friendlyError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return 'That email address is not valid.';
        case 'email-already-in-use':
          return 'An account already exists for that email.';
        case 'weak-password':
          return 'Choose a stronger password (at least 6 characters).';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Email or password is incorrect.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait and try again.';
        case 'network-request-failed':
          return 'No network connection. Check your internet and retry.';
      }
    }
    return 'Something went wrong. Please try again.';
  }
}
