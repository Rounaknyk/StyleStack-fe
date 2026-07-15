import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

typedef AuthPhoneVerificationSucceeded = void Function();
typedef AuthPhoneVerificationFailed =
    void Function(FirebaseAuthException error);
typedef AuthPhoneCodeSent =
    void Function(String verificationId, int? resendToken);
typedef AuthPhoneCodeTimedOut = void Function(String verificationId);

/// Narrow authentication contract used by [AuthProvider].
///
/// Keeping plugin calls behind this boundary makes the email, Google, and
/// callback-based phone flows deterministic in unit tests.
abstract interface class AuthGateway {
  Stream<User?> get authStateChanges;

  Future<void> signInWithEmail(String email, String password);

  Future<void> createAccountWithEmail(String email, String password);

  Future<void> signInWithGoogle();

  Future<void> startPhoneVerification({
    required String phoneNumber,
    required AuthPhoneVerificationSucceeded verificationCompleted,
    required AuthPhoneVerificationFailed verificationFailed,
    required AuthPhoneCodeSent codeSent,
    required AuthPhoneCodeTimedOut codeAutoRetrievalTimeout,
    int? forceResendingToken,
  });

  Future<void> confirmPhoneCode({
    required String verificationId,
    required String smsCode,
  });

  Future<void> signOut();
}

class AuthCancelledException implements Exception {
  const AuthCancelledException();
}

class AuthService implements AuthGateway {
  AuthService({FirebaseAuth? firebaseAuth, GoogleSignIn? googleSignIn})
    : _auth = firebaseAuth ?? FirebaseAuth.instance,
      _googleSignIn = googleSignIn ?? GoogleSignIn(scopes: const ['email']);

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  @override
  Future<void> signInWithEmail(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> createAccountWithEmail(String email, String password) async {
    await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> signInWithGoogle() async {
    final account = await _googleSignIn.signIn();
    if (account == null) throw const AuthCancelledException();

    final tokens = await account.authentication;
    if ((tokens.idToken == null || tokens.idToken!.isEmpty) &&
        (tokens.accessToken == null || tokens.accessToken!.isEmpty)) {
      throw FirebaseAuthException(
        code: 'missing-google-token',
        message: 'Google did not return an authentication token.',
      );
    }

    final credential = GoogleAuthProvider.credential(
      accessToken: tokens.accessToken,
      idToken: tokens.idToken,
    );
    await _auth.signInWithCredential(credential);
  }

  @override
  Future<void> startPhoneVerification({
    required String phoneNumber,
    required AuthPhoneVerificationSucceeded verificationCompleted,
    required AuthPhoneVerificationFailed verificationFailed,
    required AuthPhoneCodeSent codeSent,
    required AuthPhoneCodeTimedOut codeAutoRetrievalTimeout,
    int? forceResendingToken,
  }) {
    return _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      forceResendingToken: forceResendingToken,
      verificationCompleted: (credential) async {
        try {
          await _auth.signInWithCredential(credential);
          verificationCompleted();
        } on FirebaseAuthException catch (error) {
          verificationFailed(error);
        }
      },
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  @override
  Future<void> confirmPhoneCode({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    await _auth.signInWithCredential(credential);
  }

  // Compatibility wrappers for older call sites.
  Future<void> signIn(String email, String password) =>
      signInWithEmail(email, password);

  Future<void> signUp(String email, String password) =>
      createAccountWithEmail(email, password);

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Firebase sign-out is authoritative. A stale Google plugin session must
      // not prevent the user from leaving StyleStack.
    }
  }
}
