import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stylestack_fe/config/design_system.dart';
import 'package:stylestack_fe/providers/auth_provider.dart';
import 'package:stylestack_fe/screens/auth_screen.dart';
import 'package:stylestack_fe/services/auth_service.dart';

void main() {
  testWidgets('offers Google, phone, and email authentication', (tester) async {
    final gateway = _ScreenAuthGateway();
    final provider = AuthProvider(gateway);
    gateway.emitSignedOut();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: DesignSystem.buildTheme(),
          home: const AuthScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Phone'), findsOneWidget);
    expect(find.text('Continue with Email'), findsOneWidget);
    expect(find.text('FASTEST'), findsOneWidget);

    await tester.tap(find.text('Continue with Email'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('email-field')), findsOneWidget);
    expect(find.byKey(const Key('password-field')), findsOneWidget);

    provider.dispose();
    await gateway.dispose();
  });

  testWidgets('phone form advances to OTP confirmation', (tester) async {
    final gateway = _ScreenAuthGateway();
    final provider = AuthProvider(gateway);
    gateway.emitSignedOut();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: DesignSystem.buildTheme(),
          home: const AuthScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Continue with Phone'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('phone-number-field')),
      '9876543210',
    );
    await tester.tap(find.text('Send verification code'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('phone-otp-field')), findsOneWidget);
    expect(find.text('Verify and continue'), findsOneWidget);
    expect(find.text('Resend code'), findsOneWidget);

    provider.dispose();
    await gateway.dispose();
  });
}

class _ScreenAuthGateway implements AuthGateway {
  final _users = StreamController<User?>.broadcast();

  @override
  Stream<User?> get authStateChanges => _users.stream;

  void emitSignedOut() => _users.add(null);

  @override
  Future<void> createAccountWithEmail(String email, String password) async {}

  @override
  Future<void> signInWithEmail(String email, String password) async {}

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> startPhoneVerification({
    required String phoneNumber,
    required AuthPhoneVerificationSucceeded verificationCompleted,
    required AuthPhoneVerificationFailed verificationFailed,
    required AuthPhoneCodeSent codeSent,
    required AuthPhoneCodeTimedOut codeAutoRetrievalTimeout,
    int? forceResendingToken,
  }) async {
    codeSent('screen-verification', 1);
  }

  @override
  Future<void> confirmPhoneCode({
    required String verificationId,
    required String smsCode,
  }) async {}

  @override
  Future<void> signOut() async {}

  Future<void> dispose() => _users.close();
}
