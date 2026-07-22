import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import '../services/api_service.dart';

class AccessProvider extends ChangeNotifier with WidgetsBindingObserver {
  AccessProvider(this._api) {
    WidgetsBinding.instance.addObserver(this);
  }

  final ApiService _api;
  String? _userId;
  bool _loading = false;
  bool _loaded = false;
  bool _tester = false;
  bool _bypassAds = false;

  String? get userId => _userId;
  bool get loading => _loading;
  bool get loaded => _loaded;
  bool get tester => _tester;
  bool get bypassAds => _bypassAds;

  Future<void> syncUser(User user, {bool force = false}) async {
    if (_loading) return;
    if (!force && _loaded && _userId == user.uid) return;
    _loading = true;
    _userId = user.uid;
    notifyListeners();

    try {
      final access = await _api.fetchUserAccess();
      if (_userId != user.uid) return;
      _tester = access['tester'] as bool? ?? false;
      _bypassAds = access['bypass_ads'] as bool? ?? false;
    } catch (_) {
      // Tester overrides fail closed without affecting ordinary app access.
      _tester = false;
      _bypassAds = false;
    } finally {
      if (_userId == user.uid) {
        _loading = false;
        _loaded = true;
        notifyListeners();
      }
    }
  }

  void reset() {
    _userId = null;
    _loading = false;
    _loaded = false;
    _tester = false;
    _bypassAds = false;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) unawaited(syncUser(user, force: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
