import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Firebase-backed Google sign-in. Does not alter local Waffra data.
class WaffraGoogleAuth {
  WaffraGoogleAuth._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _google = GoogleSignIn.instance;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
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

  static Future<void> signOut() async {
    await _auth.signOut();
    await _google.signOut();
  }
}
