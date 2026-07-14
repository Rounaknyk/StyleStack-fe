import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._service) {
    _subscription = _service.authStateChanges.listen((user) {
      _user = user;
      _initialized = true;
      notifyListeners();
    });
  }

  final AuthService _service;
  late final StreamSubscription<User?> _subscription;
  User? _user;
  bool _initialized = false;
  bool _loading = false;
  String? _error;

  User? get user => _user;
  bool get initialized => _initialized;
  bool get loading => _loading;
  String? get error => _error;

  Future<bool> authenticate({
    required String email,
    required String password,
    required bool createAccount,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      createAccount
          ? await _service.signUp(email, password)
          : await _service.signIn(email, password);
      return true;
    } on FirebaseAuthException catch (error) {
      _error = _messageFor(error.code);
      return false;
    } catch (_) {
      _error = 'Something went wrong. Please try again.';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() => _service.signOut();

  String _messageFor(String code) => switch (code) {
    'invalid-email' => 'Enter a valid email address.',
    'weak-password' => 'Use a password with at least 6 characters.',
    'email-already-in-use' => 'An account already exists for this email.',
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' => 'Incorrect email or password.',
    'network-request-failed' => 'Check your internet connection.',
    _ => 'Authentication failed. Please try again.',
  };

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
