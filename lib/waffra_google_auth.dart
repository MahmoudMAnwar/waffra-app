import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Firebase-backed Google sign-in. Does not alter local Waffra data.
class WaffraGoogleAuth {
  WaffraGoogleAuth._();

  static FirebaseAuth get _auth => FirebaseAuth.instance;
  static final GoogleSignIn _google = GoogleSignIn.instance;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    await _google.initialize();
    _initialized = true;
  }

  static User? get currentUser => _auth.currentUser;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static Future<UserCredential> signIn() async {
    await initialize();
    final account = await _google.authenticate();
    final authentication = account.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: authentication.idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  /// Required immediately before destructive cloud account deletion.
  /// Google account identity must match the existing Firebase user;
  /// opening the app or refreshing an old token is NOT re-authentication.
  static Future<void> reauthenticateCurrentGoogleUser() async {
    await initialize();
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated Firebase account.');
    }
    final account = await _google.authenticate();
    if (user.email != null &&
        account.email.toLowerCase() != user.email!.toLowerCase()) {
      throw StateError('Please select the same Google account.');
    }
    final token = account.authentication.idToken;
    if (token == null || token.isEmpty) {
      throw StateError('Fresh Google identity token is unavailable.');
    }
    await user.reauthenticateWithCredential(
      GoogleAuthProvider.credential(idToken: token),
    );
  }

  static Future<void> signOut() async {
    await _auth.signOut();
    await _google.signOut();
  }
}
