import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/admob_config.dart';
import 'analytics_service.dart';

class InterstitialAdService {
  InterstitialAdService._();

  static final InterstitialAdService instance = InterstitialAdService._();

  InterstitialAd? _ad;
  InterstitialAd? _exportAd;
  bool _isLoadingExportAd = false;
  bool _isLoading = false;
  bool _hasShownThisSession = false;
  Timer? _sessionTimer;

  bool get _isSupported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// Call this when the user logs in or when the app starts if already logged in.
  void startSessionTimer() {
    if (!_isSupported || _hasShownThisSession || _sessionTimer != null) return;

    _loadAd();

    _sessionTimer = Timer(const Duration(minutes: 2), () {
      if (_hasShownThisSession) return;
      _showAd();
    });
  }

  void stopTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
  }

  void loadExportAd() {
    if (!_isSupported || _isLoadingExportAd || _exportAd != null) return;
    _isLoadingExportAd = true;

    InterstitialAd.load(
      adUnitId: AdMobConfig.interstitialExportStyleId(),
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _exportAd = ad;
          _isLoadingExportAd = false;
        },
        onAdFailedToLoad: (error) {
          _isLoadingExportAd = false;
          AnalyticsService.instance.event('ad_interstitial_export_failed_to_load');
        },
      ),
    );
  }

  void showExportAd({required VoidCallback onComplete}) {
    if (_exportAd == null) {
      onComplete();
      return;
    }

    _exportAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _exportAd = null;
        onComplete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _exportAd = null;
        AnalyticsService.instance.event('ad_interstitial_export_failed');
        onComplete();
      },
    );

    _exportAd!.show();
    AnalyticsService.instance.event('ad_interstitial_export_shown');
  }

  void _loadAd() {
    if (_isLoading || _ad != null) return;
    _isLoading = true;

    InterstitialAd.load(
      adUnitId: AdMobConfig.interstitialId(),
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _isLoading = false;
          _ad!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _ad = null;
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _ad = null;
              AnalyticsService.instance.event('ad_interstitial_failed');
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          AnalyticsService.instance.event('ad_interstitial_failed_to_load');
        },
      ),
    );
  }

  void _showAd() {
    if (_ad == null) {
      // Ad not loaded yet.
      return;
    }
    
    _hasShownThisSession = true;
    _ad!.show();
    _ad = null;
    AnalyticsService.instance.event('ad_interstitial_shown');
  }
}
