import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft_mobile/core/services/admob_service.dart';

void main() {
  group('AdMobService', () {
    test('bypasses ads for pro users even when config exists', () {
      expect(
        AdMobService.shouldBypassAds(
          isPro: true,
          appId: 'app-id',
          interstitialId: 'interstitial-id',
        ),
        true,
      );
    });

    test('bypasses ads when config is missing', () {
      expect(
        AdMobService.shouldBypassAds(
          isPro: false,
          appId: '',
          interstitialId: 'interstitial-id',
        ),
        true,
      );
      expect(
        AdMobService.shouldBypassAds(
          isPro: false,
          appId: 'app-id',
          interstitialId: '',
        ),
        true,
      );
    });

    test('export interstitial is attempted only for free successful flow', () {
      expect(
        AdMobService.shouldAttemptExportInterstitial(
          isPro: false,
          saveSucceeded: true,
          hasLoadedInterstitial: true,
        ),
        true,
      );
      expect(
        AdMobService.shouldAttemptExportInterstitial(
          isPro: true,
          saveSucceeded: true,
          hasLoadedInterstitial: true,
        ),
        false,
      );
      expect(
        AdMobService.shouldAttemptExportInterstitial(
          isPro: false,
          saveSucceeded: false,
          hasLoadedInterstitial: true,
        ),
        false,
      );
      expect(
        AdMobService.shouldAttemptExportInterstitial(
          isPro: false,
          saveSucceeded: true,
          hasLoadedInterstitial: false,
        ),
        false,
      );
    });
  });
}
