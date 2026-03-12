import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/app_config.dart';
import 'pro_gate.dart';

class AdMobService {
  AdMobService._();

  static InterstitialAd? _exportInterstitial;
  static bool _isInitialized = false;
  static bool _isLoadingExportInterstitial = false;

  @visibleForTesting
  static bool shouldBypassAds({
    required bool isPro,
    required String? appId,
    required String? interstitialId,
  }) {
    return isPro ||
        appId == null ||
        appId.isEmpty ||
        interstitialId == null ||
        interstitialId.isEmpty;
  }

  @visibleForTesting
  static bool shouldAttemptExportInterstitial({
    required bool isPro,
    required bool saveSucceeded,
    required bool hasLoadedInterstitial,
  }) {
    return !isPro && saveSucceeded && hasLoadedInterstitial;
  }

  static bool get _shouldBypassCurrentUser => shouldBypassAds(
    isPro: ProGate.isPro,
    appId: AppConfig.effectiveAdMobAndroidAppId,
    interstitialId: AppConfig.effectiveAdMobInterstitialExportId,
  );

  static Future<void> init() async {
    if (_shouldBypassCurrentUser) {
      developer.log(
        '[AdMob] Init bypassed. '
        'isPro=${ProGate.isPro} '
        'appIdPresent=${AppConfig.effectiveAdMobAndroidAppId != null} '
        'interstitialPresent=${AppConfig.effectiveAdMobInterstitialExportId != null}',
        name: 'Monetization',
      );
      return;
    }

    if (_isInitialized) {
      await preloadExportInterstitial();
      return;
    }

    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      developer.log(
        '[AdMob] Initialized successfully. '
        'usingDebugFallback=${AppConfig.isUsingDebugAdMobFallback}',
        name: 'Monetization',
      );
      await preloadExportInterstitial();
    } catch (e) {
      developer.log('[AdMob] Init error: $e', name: 'Monetization', error: e);
    }
  }

  static Future<void> preloadExportInterstitial() async {
    if (_shouldBypassCurrentUser) {
      _disposeExportInterstitial();
      return;
    }

    if (!_isInitialized ||
        _isLoadingExportInterstitial ||
        _exportInterstitial != null) {
      return;
    }

    final adUnitId = AppConfig.effectiveAdMobInterstitialExportId;
    if (adUnitId == null || adUnitId.isEmpty) return;

    _isLoadingExportInterstitial = true;
    developer.log(
      '[AdMob] Loading export interstitial. '
      'usingDebugFallback=${AppConfig.isUsingDebugAdMobFallback}',
      name: 'Monetization',
    );

    await InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _isLoadingExportInterstitial = false;
          _exportInterstitial = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              developer.log(
                '[AdMob] Export interstitial dismissed.',
                name: 'Monetization',
              );
              ad.dispose();
              _exportInterstitial = null;
              preloadExportInterstitial();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              developer.log(
                '[AdMob] Export interstitial failed to show: $error',
                name: 'Monetization',
              );
              ad.dispose();
              _exportInterstitial = null;
              preloadExportInterstitial();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isLoadingExportInterstitial = false;
          _exportInterstitial = null;
          developer.log(
            '[AdMob] Export interstitial failed to load: $error',
            name: 'Monetization',
          );
        },
      ),
    );
  }

  static Future<void> maybeShowExportInterstitial({
    required bool saveSucceeded,
  }) async {
    if (_shouldBypassCurrentUser) {
      _disposeExportInterstitial();
      return;
    }

    if (!shouldAttemptExportInterstitial(
      isPro: ProGate.isPro,
      saveSucceeded: saveSucceeded,
      hasLoadedInterstitial: _exportInterstitial != null,
    )) {
      if (saveSucceeded && _exportInterstitial == null) {
        await preloadExportInterstitial();
      }
      return;
    }

    final ad = _exportInterstitial;
    _exportInterstitial = null;
    if (ad == null) return;

    try {
      developer.log(
        '[AdMob] Showing export interstitial.',
        name: 'Monetization',
      );
      await ad.show();
    } catch (e) {
      developer.log(
        '[AdMob] Export interstitial show error: $e',
        name: 'Monetization',
        error: e,
      );
      ad.dispose();
      await preloadExportInterstitial();
    }
  }

  static void _disposeExportInterstitial() {
    _exportInterstitial?.dispose();
    _exportInterstitial = null;
    _isLoadingExportInterstitial = false;
  }
}
