/// Pro feature gate — local abstraction for premium features.
/// In this baseline version, isPro is always false.
/// Will be connected to Play Billing in a future task.
class ProGate {
  ProGate._();

  /// Whether the user has Pro access.
  static bool isPro = false;

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
