import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/revenuecat_config.dart';
import '../services/analytics_service.dart';
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
  bool _bypassSubscription = false;
  bool _bypassAds = false;
  bool _premium = false;
  bool _revenueCatConfigured = false;
  bool _revenueCatListenerAttached = false;
  Offering? _offering;
  String? _error;

  String? get userId => _userId;
  bool get loading => _loading;
  bool get loaded => _loaded;
  bool get tester => _tester;
  bool get premium => _premium;
  bool get bypassAds => _bypassAds || _premium;
  bool get hasAppAccess =>
      !RevenueCatConfig.subscriptionRequired || _bypassSubscription || _premium;
  bool get subscriptionRequired => RevenueCatConfig.subscriptionRequired;
  bool get storeConfigured => _revenueCatConfigured;
  Offering? get offering => _offering;
  String? get error => _error;

  Future<void> syncUser(User user, {bool force = false}) async {
    if (_loading) return;
    if (!force && _loaded && _userId == user.uid) return;
    _loading = true;
    _userId = user.uid;
    _error = null;
    notifyListeners();

    try {
      final access = await _api.fetchUserAccess();
      if (_userId != user.uid) return;
      _tester = access['tester'] as bool? ?? false;
      _bypassSubscription = access['bypass_subscription'] as bool? ?? false;
      _bypassAds = access['bypass_ads'] as bool? ?? false;
    } catch (_) {
      // Access overrides fail closed, but never prevent RevenueCat refresh or
      // ordinary app startup when subscriptions are not enforced.
      _tester = false;
      _bypassSubscription = false;
      _bypassAds = false;
    }

    try {
      await _configureRevenueCat(user.uid);
      if (_revenueCatConfigured) {
        final login = await Purchases.logIn(user.uid);
        _applyCustomerInfo(login.customerInfo);
        final offerings = await Purchases.getOfferings();
        _offering = offerings.current;
      }
    } on PlatformException catch (error) {
      _error = 'Subscriptions are temporarily unavailable.';
      debugPrint(
        'revenuecat_sync_failed code=${error.code} message=${error.message}',
      );
    } catch (error) {
      _error = 'Subscriptions are temporarily unavailable.';
      debugPrint('revenuecat_sync_failed error=$error');
    } finally {
      if (_userId == user.uid) {
        _loading = false;
        _loaded = true;
        notifyListeners();
      }
    }
  }

  Future<bool> purchase(Package package) async {
    if (!_revenueCatConfigured) return false;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      _applyCustomerInfo(result.customerInfo);
      await AnalyticsService.instance.event(
        'subscription_purchase_completed',
        parameters: {'package': package.identifier},
      );
      return _premium;
    } on PlatformException catch (error) {
      final code = PurchasesErrorHelper.getErrorCode(error);
      if (code != PurchasesErrorCode.purchaseCancelledError) {
        _error = 'The purchase could not be completed. Please try again.';
      }
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> restore() async {
    if (!_revenueCatConfigured) return false;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _applyCustomerInfo(await Purchases.restorePurchases());
      await AnalyticsService.instance.event('subscription_restore_completed');
      if (!_premium) _error = 'No active StyleStack subscription was found.';
      return _premium;
    } catch (_) {
      _error = 'Could not restore purchases. Please try again.';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _configureRevenueCat(String userId) async {
    final key = RevenueCatConfig.apiKey().trim();
    if (key.isEmpty) {
      _revenueCatConfigured = false;
      return;
    }
    if (!await Purchases.isConfigured) {
      await Purchases.configure(
        PurchasesConfiguration(key)..appUserID = userId,
      );
    }
    if (!_revenueCatListenerAttached) {
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);
      _revenueCatListenerAttached = true;
    }
    _revenueCatConfigured = true;
  }

  void _onCustomerInfoUpdated(CustomerInfo info) {
    _applyCustomerInfo(info);
    notifyListeners();
  }

  void _applyCustomerInfo(CustomerInfo info) {
    _premium = info.entitlements.active.containsKey(
      RevenueCatConfig.entitlement,
    );
  }

  void reset() {
    _userId = null;
    _loading = false;
    _loaded = false;
    _tester = false;
    _bypassSubscription = false;
    _bypassAds = false;
    _premium = false;
    _offering = null;
    _error = null;
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
    if (_revenueCatListenerAttached) {
      Purchases.removeCustomerInfoUpdateListener(_onCustomerInfoUpdated);
    }
    super.dispose();
  }
}
