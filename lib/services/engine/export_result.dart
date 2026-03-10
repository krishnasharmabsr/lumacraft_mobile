/// Structured result from video export.
class ExportResult {
  /// Path to the exported output file.
  final String outputPath;

  /// Which retry attempt succeeded: A, B, C, or D.
  final String attemptUsed;

  /// Whether a watermark was requested (free-tier user).
  final bool watermarkRequested;

  /// Whether the watermark was actually applied in the output.
  final bool watermarkApplied;

  /// If the watermark was not applied, the reason why.
  final String? fallbackReason;

  /// Full diagnostics string from all attempts.
  final String diagnostics;

  const ExportResult({
    required this.outputPath,
    required this.attemptUsed,
    required this.watermarkRequested,
    required this.watermarkApplied,
    this.fallbackReason,
    this.diagnostics = '',
  });
}
