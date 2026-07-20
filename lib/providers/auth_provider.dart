import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';
import '../services/analytics_service.dart';

enum PhoneAuthStep {
  enteringPhone,
  sendingCode,
  awaitingCode,
  verifyingCode,
  verified,
}

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._service) {
    _subscription = _service.authStateChanges.listen(
      (user) {
        _user = user;
        _initialized = true;
        AnalyticsService.instance.identifyUser(user?.uid);
        _notify();
      },
      onError: (Object _) {
        _initialized = true;
        _error = 'Could not check your sign-in status. Please try again.';
        _notify();
      },
    );
  }

  final AuthGateway _service;
  late final StreamSubscription<User?> _subscription;

  User? _user;
  bool _initialized = false;
  bool _loading = false;
  String? _error;
  PhoneAuthStep _phoneStep = PhoneAuthStep.enteringPhone;
  String? _phoneNumber;
  String? _verificationId;
  int? _resendToken;
  int _phoneAttempt = 0;
  bool _disposed = false;

  User? get user => _user;
  bool get initialized => _initialized;
  bool get loading => _loading;
  String? get error => _error;
  PhoneAuthStep get phoneStep => _phoneStep;
  String? get phoneNumber => _phoneNumber;
  bool get isAwaitingPhoneCode =>
      _phoneStep == PhoneAuthStep.awaitingCode ||
      _phoneStep == PhoneAuthStep.verifyingCode;
  bool get canResendPhoneCode =>
      _phoneStep == PhoneAuthStep.awaitingCode && !_loading;

  Future<bool> authenticateEmail({
    required String email,
    required String password,
    required bool createAccount,
  }) async {
    if (_loading) return false;
    _beginAction();
    try {
      if (createAccount) {
        await _service.createAccountWithEmail(email, password);
      } else {
        await _service.signInWithEmail(email, password);
      }
      await AnalyticsService.instance.authSucceeded(
        method: 'email',
        signUp: createAccount,
      );
      return true;
    } on FirebaseAuthException catch (error) {
      _error = _messageFor(error.code);
      return false;
    } catch (_) {
      _error = 'Something went wrong. Please try again.';
      return false;
    } finally {
      _endAction();
    }
  }

  // Compatibility for the original email-only UI and any external call sites.
  Future<bool> authenticate({
    required String email,
    required String password,
    required bool createAccount,
  }) => authenticateEmail(
    email: email,
    password: password,
    createAccount: createAccount,
  );

  Future<bool> authenticateWithGoogle() async {
    if (_loading) return false;
    _beginAction();
    try {
      await _service.signInWithGoogle();
      await AnalyticsService.instance.authSucceeded(
        method: 'google',
        signUp: false,
      );
      return true;
    } on AuthCancelledException {
      // Closing Google's account picker is an intentional action, not an error.
      return false;
    } on FirebaseAuthException catch (error) {
      _error = _messageFor(error.code);
      return false;
    } catch (_) {
      _error = 'Could not sign in with Google. Please try again.';
      return false;
    } finally {
      _endAction();
    }
  }

  Future<bool> sendPhoneOtp(String rawPhoneNumber) async {
    return _requestPhoneOtp(rawPhoneNumber, resend: false);
  }

  Future<bool> resendPhoneOtp() async {
    final number = _phoneNumber;
    if (!canResendPhoneCode || number == null) return false;
    return _requestPhoneOtp(number, resend: true);
  }

  Future<bool> _requestPhoneOtp(
    String rawPhoneNumber, {
    required bool resend,
  }) async {
    if (_loading) return false;

    late final String normalized;
    try {
      normalized = _normalizeIndianPhoneNumber(rawPhoneNumber);
    } on FormatException {
      _error = 'Enter a valid 10-digit Indian mobile number.';
      _notify();
      return false;
    }

    final attempt = ++_phoneAttempt;
    final result = Completer<bool>();
    _phoneNumber = normalized;
    _phoneStep = PhoneAuthStep.sendingCode;
    _beginAction(clearPhoneStep: false);

    bool isCurrentAttempt() => !_disposed && attempt == _phoneAttempt;
    void complete(bool value) {
      if (!result.isCompleted) result.complete(value);
    }

    try {
      await _service.startPhoneVerification(
        phoneNumber: normalized,
        forceResendingToken: resend ? _resendToken : null,
        verificationCompleted: () {
          if (!isCurrentAttempt()) return;
          _phoneStep = PhoneAuthStep.verified;
          _loading = false;
          _error = null;
          _notify();
          complete(true);
        },
        verificationFailed: (error) {
          if (!isCurrentAttempt()) return;
          _phoneStep = _verificationId == null
              ? PhoneAuthStep.enteringPhone
              : PhoneAuthStep.awaitingCode;
          _loading = false;
          _error = _messageFor(error.code);
          _notify();
          complete(false);
        },
        codeSent: (verificationId, resendToken) {
          if (!isCurrentAttempt()) return;
          _verificationId = verificationId;
          _resendToken = resendToken;
          _phoneStep = PhoneAuthStep.awaitingCode;
          _loading = false;
          _error = null;
          _notify();
          complete(true);
        },
        codeAutoRetrievalTimeout: (verificationId) {
          if (!isCurrentAttempt()) return;
          _verificationId ??= verificationId;
          _phoneStep = PhoneAuthStep.awaitingCode;
          _loading = false;
          _notify();
          complete(true);
        },
      );
    } on FirebaseAuthException catch (error) {
      if (isCurrentAttempt()) {
        _phoneStep = PhoneAuthStep.enteringPhone;
        _loading = false;
        _error = _messageFor(error.code);
        _notify();
      }
      complete(false);
    } catch (_) {
      if (isCurrentAttempt()) {
        _phoneStep = PhoneAuthStep.enteringPhone;
        _loading = false;
        _error = 'Could not send the code. Please try again.';
        _notify();
      }
      complete(false);
    }

    return result.future;
  }

  Future<bool> verifyPhoneOtp(String rawCode) async {
    if (_loading || _verificationId == null) return false;
    final code = rawCode.replaceAll(RegExp(r'\D'), '');
    if (code.length != 6) {
      _error = 'Enter the 6-digit verification code.';
      _notify();
      return false;
    }

    _phoneStep = PhoneAuthStep.verifyingCode;
    _beginAction(clearPhoneStep: false);
    try {
      await _service.confirmPhoneCode(
        verificationId: _verificationId!,
        smsCode: code,
      );
      await AnalyticsService.instance.authSucceeded(
        method: 'phone',
        signUp: false,
      );
      _phoneStep = PhoneAuthStep.verified;
      return true;
    } on FirebaseAuthException catch (error) {
      _phoneStep = PhoneAuthStep.awaitingCode;
      _error = _messageFor(error.code);
      return false;
    } catch (_) {
      _phoneStep = PhoneAuthStep.awaitingCode;
      _error = 'Could not verify the code. Please try again.';
      return false;
    } finally {
      _endAction();
    }
  }

  void resetPhoneFlow() {
    _phoneAttempt++;
    _phoneStep = PhoneAuthStep.enteringPhone;
    _phoneNumber = null;
    _verificationId = null;
    _resendToken = null;
    _loading = false;
    _error = null;
    _notify();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    _notify();
  }

  Future<void> signOut() async {
    _phoneAttempt++;
    try {
      await _service.signOut();
      await AnalyticsService.instance.event('account_signed_out');
    } finally {
      _phoneStep = PhoneAuthStep.enteringPhone;
      _phoneNumber = null;
      _verificationId = null;
      _resendToken = null;
      _loading = false;
      _error = null;
      _notify();
    }
  }

  void _beginAction({bool clearPhoneStep = true}) {
    _loading = true;
    _error = null;
    if (clearPhoneStep && _phoneStep == PhoneAuthStep.verified) {
      _phoneStep = PhoneAuthStep.enteringPhone;
    }
    _notify();
  }

  void _endAction() {
    _loading = false;
    _notify();
  }

  String _normalizeIndianPhoneNumber(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0') && digits.length == 11) {
      digits = digits.substring(1);
    }
    if (digits.length == 10) return '+91$digits';
    if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
    throw const FormatException('Invalid Indian phone number');
  }

  String _messageFor(String code) => switch (code) {
    'invalid-email' => 'Enter a valid email address.',
    'weak-password' => 'Use a password with at least 6 characters.',
    'email-already-in-use' => 'An account already exists for this email.',
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' => 'Incorrect email or password.',
    'user-disabled' => 'This account has been disabled.',
    'operation-not-allowed' =>
      'This sign-in method is not enabled yet. Please choose another option.',
    'account-exists-with-different-credential' =>
      'An account already exists with this email. Use its original sign-in method.',
    'credential-already-in-use' =>
      'This sign-in method is already linked to another account.',
    'invalid-phone-number' => 'Enter a valid 10-digit Indian mobile number.',
    'invalid-verification-code' => 'That code is incorrect. Please try again.',
    'invalid-verification-id' ||
    'session-expired' => 'That code has expired. Request a new one.',
    'too-many-requests' =>
      'Too many attempts. Please wait a little before trying again.',
    'quota-exceeded' => 'The SMS limit was reached. Please try again later.',
    'missing-google-token' ||
    'missing-client-identifier' ||
    'app-not-authorized' =>
      'Google sign-in is not configured correctly for this device.',
    'network-request-failed' => 'Check your internet connection.',
    _ => 'Authentication failed. Please try again.',
  };

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _phoneAttempt++;
    _subscription.cancel();
    super.dispose();
  }
}
