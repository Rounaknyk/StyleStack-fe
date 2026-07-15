import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:stylestack_fe/providers/auth_provider.dart';
import 'package:stylestack_fe/services/auth_service.dart';

void main() {
  late _FakeAuthGateway gateway;
  late AuthProvider provider;

  setUp(() {
    gateway = _FakeAuthGateway();
    provider = AuthProvider(gateway);
    gateway.emitUser(null);
  });

  tearDown(() async {
    provider.dispose();
    await gateway.dispose();
  });

  test(
    'email sign-in and sign-up use the requested Firebase operation',
    () async {
      expect(
        await provider.authenticateEmail(
          email: ' person@example.com ',
          password: 'password',
          createAccount: false,
        ),
        isTrue,
      );
      expect(gateway.emailSignIns, 1);
      expect(gateway.emailCreations, 0);

      expect(
        await provider.authenticateEmail(
          email: 'new@example.com',
          password: 'password',
          createAccount: true,
        ),
        isTrue,
      );
      expect(gateway.emailCreations, 1);
      expect(provider.loading, isFalse);
      expect(provider.error, isNull);
    },
  );

  test('closing Google sign-in is not surfaced as an error', () async {
    gateway.googleError = const AuthCancelledException();

    expect(await provider.authenticateWithGoogle(), isFalse);
    expect(provider.error, isNull);
    expect(provider.loading, isFalse);
  });

  test(
    'phone flow normalizes +91, supports resend, and verifies code',
    () async {
      expect(await provider.sendPhoneOtp('98765 43210'), isTrue);
      expect(gateway.lastPhoneNumber, '+919876543210');
      expect(provider.phoneStep, PhoneAuthStep.awaitingCode);
      expect(provider.canResendPhoneCode, isTrue);

      expect(await provider.resendPhoneOtp(), isTrue);
      expect(gateway.lastForceResendingToken, 73);

      expect(await provider.verifyPhoneOtp('123456'), isTrue);
      expect(gateway.confirmedVerificationId, 'verification-2');
      expect(gateway.confirmedCode, '123456');
      expect(provider.phoneStep, PhoneAuthStep.verified);
    },
  );

  test(
    'invalid OTP receives a useful Firebase error and remains retryable',
    () async {
      await provider.sendPhoneOtp('9876543210');
      gateway.confirmError = FirebaseAuthException(
        code: 'invalid-verification-code',
      );

      expect(await provider.verifyPhoneOtp('000000'), isFalse);
      expect(provider.phoneStep, PhoneAuthStep.awaitingCode);
      expect(provider.error, 'That code is incorrect. Please try again.');
      expect(provider.canResendPhoneCode, isTrue);
    },
  );

  test('invalid Indian number is rejected before Firebase is called', () async {
    expect(await provider.sendPhoneOtp('1234'), isFalse);
    expect(gateway.phoneRequests, 0);
    expect(provider.error, 'Enter a valid 10-digit Indian mobile number.');
  });

  test('Firebase phone failure is mapped and resets the entry state', () async {
    gateway.phoneError = FirebaseAuthException(code: 'too-many-requests');

    expect(await provider.sendPhoneOtp('9876543210'), isFalse);
    expect(provider.phoneStep, PhoneAuthStep.enteringPhone);
    expect(
      provider.error,
      'Too many attempts. Please wait a little before trying again.',
    );
  });
}

class _FakeAuthGateway implements AuthGateway {
  final _users = StreamController<User?>.broadcast();

  int emailSignIns = 0;
  int emailCreations = 0;
  int phoneRequests = 0;
  String? lastPhoneNumber;
  int? lastForceResendingToken;
  String? confirmedVerificationId;
  String? confirmedCode;
  Object? googleError;
  FirebaseAuthException? phoneError;
  FirebaseAuthException? confirmError;

  @override
  Stream<User?> get authStateChanges => _users.stream;

  void emitUser(User? user) => _users.add(user);

  @override
  Future<void> signInWithEmail(String email, String password) async {
    emailSignIns++;
  }

  @override
  Future<void> createAccountWithEmail(String email, String password) async {
    emailCreations++;
  }

  @override
  Future<void> signInWithGoogle() async {
    final error = googleError;
    if (error != null) throw error;
  }

  @override
  Future<void> startPhoneVerification({
    required String phoneNumber,
    required AuthPhoneVerificationSucceeded verificationCompleted,
    required AuthPhoneVerificationFailed verificationFailed,
    required AuthPhoneCodeSent codeSent,
    required AuthPhoneCodeTimedOut codeAutoRetrievalTimeout,
    int? forceResendingToken,
  }) async {
    phoneRequests++;
    lastPhoneNumber = phoneNumber;
    lastForceResendingToken = forceResendingToken;
    if (phoneError case final error?) {
      verificationFailed(error);
      return;
    }
    codeSent('verification-$phoneRequests', 73);
  }

  @override
  Future<void> confirmPhoneCode({
    required String verificationId,
    required String smsCode,
  }) async {
    confirmedVerificationId = verificationId;
    confirmedCode = smsCode;
    if (confirmError case final error?) throw error;
  }

  @override
  Future<void> signOut() async {}

  Future<void> dispose() => _users.close();
}
