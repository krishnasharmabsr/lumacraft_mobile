enum ExportQualityPreset {
  low('Low', 6, '96k'),
  standard('Standard', 4, '128k'),
  high('High', 2, '192k');

  final String label;
  final int qv;
  final String audioBitrate;

  const ExportQualityPreset(this.label, this.qv, this.audioBitrate);
}

class ExportSettings {
  final ExportResolution resolution;
  final int? fps; // null means 'Source'
  final ExportQualityPreset qualityPreset;
  final ExportFormat format;

  const ExportSettings({
    this.resolution = ExportResolution.p720,
    this.fps, // default Source
    this.qualityPreset = ExportQualityPreset.standard,
    this.format = ExportFormat.mp4,
  });

  /// Returns the FFmpeg scale filter string, e.g. "-vf scale=-2:720"
  String get scaleFilter {
    return 'scale=-2:${resolution.height}';
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
