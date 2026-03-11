import '../config/app_config.dart';

/// Pro feature gate - local abstraction for premium features.
/// Connected to RevenueCat for production entitlement.
class ProGate {
  ProGate._();

  static bool _revenueCatEntitled = false;

  /// Whether the user has Pro access.
  /// Includes a strict debug-only QA override if enabled.
  static bool get isPro {
    if (AppConfig.isDevProOverrideEnabled) return true;
    return _revenueCatEntitled;
  }

  /// Updates the raw revenue cat entitlement status (called by RevenueCatService).
  static set isPro(bool value) {
    _revenueCatEntitled = value;
  }

  /// Returns true if the feature requires Pro and user is not Pro.
  static bool isLocked(ProFeature feature) {
    if (isPro) return false;
    return feature.requiresPro;
  }
}

/// Features that can be gated behind Pro.
enum ProFeature {
  resolution1080p(true),
  resolution4K(true),
  fps60(true),
  formatMkv(false); // free for now

  final bool requiresPro;
  const ProFeature(this.requiresPro);
}
