import 'package:flutter/foundation.dart';

/// Centralized configuration access for the app.
class AppConfig {
  /// RevenueCat Android API key, injected via --dart-define=RC_ANDROID_KEY=...
  static const String revenueCatAndroidKey = String.fromEnvironment(
    'RC_ANDROID_KEY',
  );

  /// AdMob Android app ID, injected via --dart-define=ADMOB_ANDROID_APP_ID=...
  static const String adMobAndroidAppId = String.fromEnvironment(
    'ADMOB_ANDROID_APP_ID',
  );

  /// AdMob interstitial unit ID for export-complete placement.
  static const String adMobInterstitialExportId = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_EXPORT_ID',
  );

  /// Developer override to force Pro entitlement in debug mode.
  /// Injected via --dart-define=DEV_FORCE_PRO=true
  static const bool _devForcePro = bool.fromEnvironment(
    'DEV_FORCE_PRO',
    defaultValue: false,
  );

  static const String _debugTestAdMobAppId =
      'ca-app-pub-3940256099942544~3347511713';
  static const String _debugTestInterstitialExportId =
      'ca-app-pub-3940256099942544/1033173712';

  /// True if we are in debug mode AND the force-pro override is enabled.
  /// This strictly protects release builds from accidental pro unlocks.
  static bool get isDevProOverrideEnabled => kDebugMode && _devForcePro;

  static bool get hasAdMobRuntimeConfig =>
      adMobAndroidAppId.isNotEmpty && adMobInterstitialExportId.isNotEmpty;

  static bool get isUsingDebugAdMobFallback =>
      kDebugMode && !hasAdMobRuntimeConfig;

  static String? get effectiveAdMobAndroidAppId {
    if (adMobAndroidAppId.isNotEmpty) return adMobAndroidAppId;
    if (kDebugMode) return _debugTestAdMobAppId;
    return null;
  }

  static String? get effectiveAdMobInterstitialExportId {
    if (adMobInterstitialExportId.isNotEmpty) {
      return adMobInterstitialExportId;
    }
    if (kDebugMode) return _debugTestInterstitialExportId;
    return null;
  }
}
