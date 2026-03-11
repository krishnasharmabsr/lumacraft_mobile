class VideoFilter {
  final String label;
  final String? ffmpegFilter;
  final List<double>? matrix;

  const VideoFilter({required this.label, this.ffmpegFilter, this.matrix});

  static const original = VideoFilter(label: 'Original');
  static const bright = VideoFilter(
    label: 'Bright',
    ffmpegFilter: 'eq=brightness=0.06',
    matrix: [
      1.0,
      0,
      0,
      0,
      15,
      0,
      1.0,
      0,
      0,
      15,
      0,
      0,
      1.0,
      0,
      15,
      0,
      0,
      0,
      1,
      0,
    ],
  );
  static const contrast = VideoFilter(
    label: 'Contrast',
    ffmpegFilter: 'eq=contrast=1.3',
    matrix: [
      1.3,
      0,
      0,
      0,
      -38,
      0,
      1.3,
      0,
      0,
      -38,
      0,
      0,
      1.3,
      0,
      -38,
      0,
      0,
      0,
      1,
      0,
    ],
  );
  static const warm = VideoFilter(
    label: 'Warm',
    ffmpegFilter: 'colorbalance=rs=0.1:gs=0.05:bs=-0.1',
    matrix: [1.1, 0, 0, 0, 0, 0, 1.05, 0, 0, 0, 0, 0, 0.9, 0, 0, 0, 0, 0, 1, 0],
  );
  static const cool = VideoFilter(
    label: 'Cool',
    ffmpegFilter: 'colorbalance=rs=-0.1:gs=0.05:bs=0.1',
    matrix: [0.9, 0, 0, 0, 0, 0, 1.05, 0, 0, 0, 0, 0, 1.1, 0, 0, 0, 0, 0, 1, 0],
  );
  static const vintage = VideoFilter(
    label: 'Vintage',
    ffmpegFilter:
        'colorchannelmixer=.393:.769:.189:0:.349:.686:.168:0:.272:.534:.131',
    matrix: [
      0.393,
      0.769,
      0.189,
      0,
      0,
      0.349,
      0.686,
      0.168,
      0,
      0,
      0.272,
      0.534,
      0.131,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ],
  );
  static const blackAndWhite = VideoFilter(
    label: 'B&W',
    ffmpegFilter: 'hue=s=0',
    matrix: [
      0.2126,
      0.7152,
      0.0722,
      0,
      0,
      0.2126,
      0.7152,
      0.0722,
      0,
      0,
      0.2126,
      0.7152,
      0.0722,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ],
  );

  static const List<VideoFilter> all = [
    original,
    bright,
    contrast,
    warm,
    cool,
    vintage,
    blackAndWhite,
  ];

  bool get isOriginal => ffmpegFilter == null || matrix == null;

  static VideoFilter fromLabel(String? label) {
    for (final filter in all) {
      if (filter.label == label) {
        return filter;
      }
    }
    return original;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoFilter &&
          runtimeType == other.runtimeType &&
          label == other.label;

  @override
  int get hashCode => label.hashCode;
}
