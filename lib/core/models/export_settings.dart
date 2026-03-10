class ExportSettings {
  final ExportResolution resolution;
  final ExportAspectRatio aspectRatio;
  final double playbackSpeed;
  final int? fps; // null means 'Source'
  final int quality; // 0–100 slider value
  final ExportFormat format;

  const ExportSettings({
    this.resolution = ExportResolution.p720,
    this.aspectRatio = ExportAspectRatio.source,
    this.playbackSpeed = 1.0,
    this.fps, // default Source
    this.quality = 65,
    this.format = ExportFormat.mp4,
  });

  /// Returns the FFmpeg scale filter string, e.g. "-vf scale=-2:720"
  /// If an aspect ratio is forced, adds pad filter to prevent stretching.
  String get scaleFilter {
    if (aspectRatio == ExportAspectRatio.source) {
      return 'scale=-2:${resolution.height}';
    }

    final targetWidth = (resolution.height * aspectRatio.ratio!).round();
    // Use force_original_aspect_ratio=decrease to fit within target bounding box,
    // then pad with black background to fill the exact aspect ratio frame.
    return 'scale=$targetWidth:${resolution.height}:force_original_aspect_ratio=decrease,pad=$targetWidth:${resolution.height}:(ow-iw)/2:(oh-ih)/2:black';
  }

  /// Maps 0–100 quality slider to mpeg4 q:v (1=best, 10=worst).
  int get qualityValue {
    // 0→10 (worst), 50→5 (medium), 100→1 (best)
    return (10 - (quality * 9 / 100)).round().clamp(1, 10);
  }

  /// Maps quality to audio bitrate.
  String get audioBitrate {
    if (quality >= 75) return '192k';
    if (quality >= 40) return '128k';
    return '96k';
  }

  /// User-friendly quality label.
  String get qualityLabel {
    if (quality >= 75) return 'High';
    if (quality >= 40) return 'Standard';
    return 'Low';
  }

  /// File extension.
  String get extension => format.extension;
}

enum ExportResolution {
  p480(480, '480p', false),
  p720(720, '720p', false),
  p1080(1080, '1080p', true),
  p4K(2160, '4K', true);

  final int height;
  final String label;
  final bool requiresPro;
  const ExportResolution(this.height, this.label, this.requiresPro);
}

enum ExportFormat {
  mp4('mp4', 'MP4'),
  mkv('mkv', 'MKV');

  final String extension;
  final String label;
  const ExportFormat(this.extension, this.label);
}

enum ExportAspectRatio {
  source('Source', null),
  vertical('9:16', 9 / 16),
  square('1:1', 1.0),
  horizontal('16:9', 16 / 9);

  final String label;
  final double? ratio; // null means source (no forcing)
  const ExportAspectRatio(this.label, this.ratio);
}
