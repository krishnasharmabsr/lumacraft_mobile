/// Export settings model for LumaCraft export studio.
class ExportSettings {
  final ExportResolution resolution;
  final int fps;
  final ExportQuality quality;
  final String format;

  const ExportSettings({
    this.resolution = ExportResolution.p720,
    this.fps = 30,
    this.quality = ExportQuality.medium,
    this.format = 'mp4',
  });

  /// Returns the FFmpeg scale filter string, e.g. "-vf scale=-2:720"
  String get scaleFilter {
    return '-vf scale=-2:${resolution.height}';
  }

  /// Returns the quality-based CRF / q:v value for mpeg4 encoder.
  int get qualityValue {
    switch (quality) {
      case ExportQuality.low:
        return 6;
      case ExportQuality.medium:
        return 3;
      case ExportQuality.high:
        return 1;
    }
  }

  /// Returns audio bitrate string based on quality.
  String get audioBitrate {
    switch (quality) {
      case ExportQuality.low:
        return '96k';
      case ExportQuality.medium:
        return '128k';
      case ExportQuality.high:
        return '192k';
    }
  }
}

enum ExportResolution {
  p480(480, '480p'),
  p720(720, '720p'),
  p1080(1080, '1080p');

  final int height;
  final String label;
  const ExportResolution(this.height, this.label);
}

enum ExportQuality {
  low('Low'),
  medium('Medium'),
  high('High');

  final String label;
  const ExportQuality(this.label);
}
