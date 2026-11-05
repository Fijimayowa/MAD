import 'package:firebase_auth/firebase_auth.dart';

/// All Firebase Authentication calls live here; widgets only call this class.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  /// Created once so the same stream is reused on every rebuild.
  late final Stream<User?> authStateChanges = _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> register(String email, String password) async {
    await _auth.createUserWithEmailAndPassword(
        email: email.trim(), password: password);
  }

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
        email: email.trim(), password: password);
  }

  Future<void> signOut() => _auth.signOut();

  /// May throw FirebaseAuthException with code 'requires-recent-login'.
  Future<void> updatePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'no-current-user');
    }
    await user.updatePassword(newPassword);
  }

  /// Re-verifies the current user so a sensitive action can be retried.
  Future<void> reauthenticate(String currentPassword) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw FirebaseAuthException(code: 'no-current-user');
    }
    final credential =
        EmailAuthProvider.credential(email: email, password: currentPassword);
    await user.reauthenticateWithCredential(credential);
  }
}

/// Turns Firebase error codes into safe, helpful messages (no raw exceptions).
String authErrorMessage(String code) {
  switch (code) {
    case 'invalid-email':
      return 'That email address does not look valid.';
    case 'user-disabled':
      return 'This account has been disabled.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'Email or password is incorrect. Please try again.';
    case 'email-already-in-use':
      return 'An account already exists for that email. Try signing in.';
    case 'weak-password':
      return 'Password is too weak. Use at least 6 characters.';
    case 'network-request-failed':
      return 'Network problem. Check your connection and try again.';
    case 'too-many-requests':
      return 'Too many attempts. Please wait a bit and try again.';
    case 'requires-recent-login':
      return 'For security, please confirm your current password.';
    case 'operation-not-allowed':
      return 'Email/password sign-in is not enabled for this project.';
    case 'no-current-user':
      return 'You are not signed in.';
    default:
      return 'Something went wrong. Please try again.';
  }
}
