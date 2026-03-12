import 'package:flutter/foundation.dart';

/// Centralized configuration access for the app.
class AppConfig {
  /// RevenueCat Android API key, injected via --dart-define=RC_ANDROID_KEY=...
  static const String revenueCatAndroidKey = String.fromEnvironment('RC_ANDROID_KEY');

  /// Developer override to force Pro entitlement in debug mode.
  /// Injected via --dart-define=DEV_FORCE_PRO=true
  static const bool _devForcePro = bool.fromEnvironment('DEV_FORCE_PRO', defaultValue: false);

  /// True if we are in debug mode AND the force-pro override is enabled.
  /// This strictly protects release builds from accidental pro unlocks.
  static bool get isDevProOverrideEnabled => kDebugMode && _devForcePro;
}
