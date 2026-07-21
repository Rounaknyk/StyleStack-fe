import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/admob_config.dart';
import 'analytics_service.dart';

enum RewardedPlacement { dailyOutfit, calendarConnection }

enum RewardedAdOutcome { earned, dismissed, unavailable, failed }

enum DailyRefreshAccess { free, bonus, rewardedAdRequired }

/// Owns AdMob rewarded-ad lifecycle and the small device-local reward ledger.
///
/// The ledger keeps this MVP responsive and avoids a backend round trip. It is
/// not intended as fraud-resistant billing state; move it server-side before
/// rewards have monetary value.
class RewardedAdService {
  RewardedAdService._();

  static final RewardedAdService instance = RewardedAdService._();

  static const int freeDailyRefreshes = 2;
  final Map<RewardedPlacement, RewardedAd?> _ads = {};
  final Map<RewardedPlacement, Future<bool>> _loads = {};
  bool _initialized = false;
  bool _available = true;

  bool get _isSupported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> initialize() async {
    if (_initialized || !_isSupported) return;
    _initialized = true;
    try {
      await MobileAds.instance.initialize();
      unawaited(_ensureLoaded(RewardedPlacement.dailyOutfit));
      unawaited(_ensureLoaded(RewardedPlacement.calendarConnection));
    } catch (error) {
      _available = false;
      debugPrint('admob_initialization_failed error=$error');
      await AnalyticsService.instance.event('admob_initialization_failed');
    }
  }

  Future<RewardedAdOutcome> show(RewardedPlacement placement) async {
    if (!_isSupported) return RewardedAdOutcome.unavailable;
    await initialize();
    if (!_available) return RewardedAdOutcome.unavailable;
    if (!await _ensureLoaded(placement)) {
      await AnalyticsService.instance.event(
        'rewarded_ad_unavailable',
        parameters: {'placement': placement.name},
      );
      return RewardedAdOutcome.unavailable;
    }

    final ad = _ads.remove(placement);
    if (ad == null) return RewardedAdOutcome.unavailable;

    final result = Completer<RewardedAdOutcome>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdShowedFullScreenContent: (_) {
        unawaited(
          AnalyticsService.instance.event(
            'rewarded_ad_shown',
            parameters: {'placement': placement.name},
          ),
        );
      },
      onAdDismissedFullScreenContent: (shownAd) {
        shownAd.dispose();
        if (!result.isCompleted) {
          result.complete(
            earned ? RewardedAdOutcome.earned : RewardedAdOutcome.dismissed,
          );
        }
        unawaited(_ensureLoaded(placement));
      },
      onAdFailedToShowFullScreenContent: (failedAd, error) {
        failedAd.dispose();
        debugPrint(
          'rewarded_ad_show_failed placement=${placement.name} '
          'code=${error.code} domain=${error.domain} message=${error.message}',
        );
        unawaited(
          AnalyticsService.instance.event(
            'rewarded_ad_show_failed',
            parameters: {'placement': placement.name, 'error_code': error.code},
          ),
        );
        if (!result.isCompleted) result.complete(RewardedAdOutcome.failed);
        unawaited(_ensureLoaded(placement));
      },
    );

    try {
      await ad.show(
        onUserEarnedReward: (_, reward) {
          earned = true;
          unawaited(
            AnalyticsService.instance.event(
              'rewarded_ad_earned',
              parameters: {
                'placement': placement.name,
                'reward_amount': reward.amount.toDouble(),
              },
            ),
          );
        },
      );
    } catch (error) {
      await ad.dispose();
      debugPrint(
        'rewarded_ad_show_exception placement=${placement.name} error=$error',
      );
      if (!result.isCompleted) result.complete(RewardedAdOutcome.failed);
      unawaited(_ensureLoaded(placement));
    }
    return result.future;
  }

  Future<DailyRefreshAccess> dailyRefreshAccess(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    final freeUsed = preferences.getInt(_freeRefreshKey(userId)) ?? 0;
    if (freeUsed < freeDailyRefreshes) return DailyRefreshAccess.free;
    final bonuses = preferences.getInt(_bonusRefreshKey(userId)) ?? 0;
    if (bonuses > 0) return DailyRefreshAccess.bonus;
    return DailyRefreshAccess.rewardedAdRequired;
  }

  /// Commits an allowance only after the outfit API succeeds, so failed
  /// generations never consume a free refresh or an earned reward.
  Future<void> consumeRefresh(String userId, DailyRefreshAccess access) async {
    final preferences = await SharedPreferences.getInstance();
    switch (access) {
      case DailyRefreshAccess.free:
        final key = _freeRefreshKey(userId);
        await preferences.setInt(key, (preferences.getInt(key) ?? 0) + 1);
        break;
      case DailyRefreshAccess.bonus:
        final key = _bonusRefreshKey(userId);
        final current = preferences.getInt(key) ?? 0;
        await preferences.setInt(key, current > 0 ? current - 1 : 0);
        break;
      case DailyRefreshAccess.rewardedAdRequired:
        break;
    }
  }

  Future<void> grantBonusRefresh(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    final key = _bonusRefreshKey(userId);
    await preferences.setInt(key, (preferences.getInt(key) ?? 0) + 1);
  }

  Future<bool> hasSeenCalendarOffer(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_calendarOfferKey(userId)) ?? false;
  }

  Future<void> markCalendarOfferSeen(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_calendarOfferKey(userId), true);
  }

  Future<bool> _ensureLoaded(RewardedPlacement placement) {
    if (_ads[placement] != null) return Future.value(true);
    final active = _loads[placement];
    if (active != null) return active;

    final completer = Completer<bool>();
    _loads[placement] = completer.future;
    final adUnitId = switch (placement) {
      RewardedPlacement.dailyOutfit => AdMobConfig.rewardedDailyOutfitId(),
      RewardedPlacement.calendarConnection => AdMobConfig.rewardedCalendarId(),
    };
    if (adUnitId.isEmpty) {
      _loads.remove(placement);
      completer.complete(false);
      return completer.future;
    }

    try {
      RewardedAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _ads[placement] = ad;
            _loads.remove(placement);
            if (!completer.isCompleted) completer.complete(true);
          },
          onAdFailedToLoad: (error) {
            debugPrint(
              'rewarded_ad_load_failed placement=${placement.name} '
              'code=${error.code} domain=${error.domain} message=${error.message}',
            );
            unawaited(
              AnalyticsService.instance.event(
                'rewarded_ad_load_failed',
                parameters: {
                  'placement': placement.name,
                  'error_code': error.code,
                },
              ),
            );
            _loads.remove(placement);
            if (!completer.isCompleted) completer.complete(false);
          },
        ),
      );
    } catch (error) {
      debugPrint(
        'rewarded_ad_load_exception placement=${placement.name} error=$error',
      );
      _loads.remove(placement);
      if (!completer.isCompleted) completer.complete(false);
    }
    return completer.future;
  }

  String _freeRefreshKey(String userId) {
    final now = DateTime.now();
    final day =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    return 'daily_outfit_refreshes_${Uri.encodeComponent(userId)}_$day';
  }

  String _bonusRefreshKey(String userId) =>
      'rewarded_bonus_outfit_refreshes_${Uri.encodeComponent(userId)}';

  String _calendarOfferKey(String userId) =>
      'calendar_reward_offer_seen_${Uri.encodeComponent(userId)}';
}
