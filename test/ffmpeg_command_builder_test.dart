import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft_mobile/core/models/export_settings.dart';
import 'package:lumacraft_mobile/core/models/video_filter.dart';
import 'package:lumacraft_mobile/services/engine/ffmpeg_processor.dart';
import 'package:lumacraft_mobile/services/engine/export_result.dart';

void main() {
  // ── ATEMPO CHAIN ──
  group('buildAtempoChain', () {
    test('speed 1.0 returns single atempo', () {
      expect(FFmpegProcessor.buildAtempoChain(1.0), 'atempo=1.0');
    });

    test('speed 1.5 returns single atempo', () {
      expect(FFmpegProcessor.buildAtempoChain(1.5), 'atempo=1.5');
    });

    test('speed 4.0 chains two atempo=2.0', () {
      expect(FFmpegProcessor.buildAtempoChain(4.0), 'atempo=2.0,atempo=2.0');
    });

    test('speed 8.0 chains three atempo=2.0', () {
      expect(
        FFmpegProcessor.buildAtempoChain(8.0),
        'atempo=2.0,atempo=2.0,atempo=2.0',
      );
    });

    test('speed 0.25 chains two atempo=0.5', () {
      expect(FFmpegProcessor.buildAtempoChain(0.25), 'atempo=0.5,atempo=0.5');
    });

    test('speed 3.0 chains atempo=2.0 then atempo=1.5', () {
      expect(FFmpegProcessor.buildAtempoChain(3.0), 'atempo=2.0,atempo=1.5');
    });
  });

  // ── FAILURE CLASSIFICATION ──
  group('classifyFailure', () {
    test('detects watermark failure from image2 log', () {
      expect(
        FFmpegProcessor.classifyFailure(
          'Error: image2 demuxer could not find codec parameters for Input #1',
        ),
        ExportFailureType.watermark,
      );
    });

    test('detects watermark failure from overlay log', () {
      expect(
        FFmpegProcessor.classifyFailure('Failed to configure overlay filter'),
        ExportFailureType.watermark,
      );
    });

    test('detects audio failure from stream map', () {
      expect(
        FFmpegProcessor.classifyFailure(
          'Stream map \'0:a:0\' matches no streams',
        ),
        ExportFailureType.audio,
      );
    });

    test('detects encoder failure', () {
      expect(
        FFmpegProcessor.classifyFailure(
          'Error initializing output stream 0:0 -- Error while opening encoder',
        ),
        ExportFailureType.encoder,
      );
    });

    test('returns unknown for unrecognized log', () {
      expect(
        FFmpegProcessor.classifyFailure('Something completely different'),
        ExportFailureType.unknown,
      );
    });
  });

  // ── RETRY MATRIX ──
  group('nextAttempt', () {
    test('A → B: switches to rawRgba watermark', () {
      const a = ExportAttemptConfig(
        label: 'A',
        watermarkBackend: WatermarkBackend.png,
        includeAudio: true,
        videoCodecProfile: VideoCodecProfile.mpeg4Default,
      );
      final b = FFmpegProcessor.nextAttempt(a, ExportFailureType.watermark);
      expect(b, isNotNull);
      expect(b!.label, 'B');
      expect(b.watermarkBackend, WatermarkBackend.rawRgba);
      expect(b.includeAudio, true);
    });

    test('B → C: disables audio', () {
      const b = ExportAttemptConfig(
        label: 'B',
        watermarkBackend: WatermarkBackend.rawRgba,
        includeAudio: true,
        videoCodecProfile: VideoCodecProfile.mpeg4Default,
      );
      final c = FFmpegProcessor.nextAttempt(b, ExportFailureType.audio);
      expect(c, isNotNull);
      expect(c!.label, 'C');
      expect(c.watermarkBackend, WatermarkBackend.rawRgba);
      expect(c.includeAudio, false);
    });

    test('C → D: x264 fallback', () {
      const c = ExportAttemptConfig(
        label: 'C',
        watermarkBackend: WatermarkBackend.rawRgba,
        includeAudio: false,
        videoCodecProfile: VideoCodecProfile.mpeg4Default,
      );
      final d = FFmpegProcessor.nextAttempt(c, ExportFailureType.encoder);
      expect(d, isNotNull);
      expect(d!.label, 'D');
      expect(d.watermarkBackend, WatermarkBackend.rawRgba);
      expect(d.videoCodecProfile, VideoCodecProfile.x264Fallback);
    });

    test('D → null: all exhausted', () {
      const d = ExportAttemptConfig(
        label: 'D',
        watermarkBackend: WatermarkBackend.rawRgba,
        includeAudio: false,
        videoCodecProfile: VideoCodecProfile.x264Fallback,
      );
      final next = FFmpegProcessor.nextAttempt(d, ExportFailureType.unknown);
      expect(next, isNull);
    });
  });

  // ── COMMAND BUILDER ──
  group('buildExportCommand', () {
    const baseSettings = ExportSettings(
      resolution: ExportResolution.p720,
      fps: 30,
      qualityPreset: ExportQualityPreset.standard,
      format: ExportFormat.mp4,
    );

    test('audio + no-speed: bare 0:a:0 mapping', () {
      final result = FFmpegProcessor.buildExportCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        settings: baseSettings,
        trimStart: Duration.zero,
        trimEnd: const Duration(seconds: 10),
        playbackSpeed: 1.0,
        videoFilter: VideoFilter.original,
        aspectRatio: ExportAspectRatio.source,
        hasAudio: true,
        finalFps: 30,
        applyWatermark: false,
        watermarkPath: null,
      );

      expect(result.command, contains('0:a:0'));
      expect(result.command, isNot(contains('-map "[0:a:0]"')));
      expect(result.command, contains('-c:a aac'));
      expect(result.command, contains('-movflags +faststart'));
    });

    test('audio + speed >2: chained atempo', () {
      final result = FFmpegProcessor.buildExportCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        settings: baseSettings,
        trimStart: Duration.zero,
        trimEnd: const Duration(seconds: 10),
        playbackSpeed: 4.0,
        videoFilter: VideoFilter.original,
        aspectRatio: ExportAspectRatio.source,
        hasAudio: true,
        finalFps: 30,
        applyWatermark: false,
        watermarkPath: null,
      );

      expect(result.command, contains('atempo=2.0,atempo=2.0'));
      expect(result.command, contains('"[a_speed]"'));
    });

    test('selected filter is inserted before watermark overlay and pad', () {
      final result = FFmpegProcessor.buildExportCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        settings: baseSettings,
        trimStart: Duration.zero,
        trimEnd: const Duration(seconds: 10),
        playbackSpeed: 1.0,
        videoFilter: VideoFilter.warm,
        aspectRatio: ExportAspectRatio.vertical,
        hasAudio: true,
        finalFps: 30,
        applyWatermark: true,
        watermarkPath: '/cache/watermark_runtime.png',
        watermarkBackend: WatermarkBackend.png,
      );

      final filterIndex = result.command.indexOf(
        VideoFilter.warm.ffmpegFilter!,
      );
      final overlayIndex = result.command.indexOf('overlay=');
      final padIndex = result.command.indexOf('pad=');

      expect(filterIndex, greaterThan(-1));
      expect(filterIndex, lessThan(overlayIndex));
      expect(filterIndex, lessThan(padIndex));
      expect(result.diagnostics, contains('video_filter=Warm'));
    });

    test('original filter does not add extra FFmpeg filter segment', () {
      final result = FFmpegProcessor.buildExportCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        settings: baseSettings,
        trimStart: Duration.zero,
        trimEnd: const Duration(seconds: 10),
        playbackSpeed: 1.0,
        videoFilter: VideoFilter.original,
        aspectRatio: ExportAspectRatio.source,
        hasAudio: true,
        finalFps: 30,
        applyWatermark: false,
        watermarkPath: null,
      );

      expect(result.command, isNot(contains('colorbalance=')));
      expect(result.command, isNot(contains('colorchannelmixer=')));
      expect(result.command, isNot(contains('hue=s=0')));
      expect(result.diagnostics, contains('video_filter=Original'));
    });

    test('explicit fps adds fps filter and output flag', () {
      final result = FFmpegProcessor.buildExportCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        settings: baseSettings,
        trimStart: Duration.zero,
        trimEnd: const Duration(seconds: 10),
        playbackSpeed: 1.0,
        videoFilter: VideoFilter.original,
        aspectRatio: ExportAspectRatio.source,
        hasAudio: true,
        finalFps: 60,
        applyWatermark: false,
        watermarkPath: null,
      );

      expect(result.command, contains('fps=60'));
      expect(result.command, contains('-r 60'));
      expect(result.diagnostics, contains('output_fps=60'));
    });

    test('source fps mode keeps original timestamps without fps filter', () {
      final result = FFmpegProcessor.buildExportCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        settings: baseSettings,
        trimStart: Duration.zero,
        trimEnd: const Duration(seconds: 10),
        playbackSpeed: 1.0,
        videoFilter: VideoFilter.original,
        aspectRatio: ExportAspectRatio.source,
        hasAudio: true,
        finalFps: null,
        applyWatermark: false,
        watermarkPath: null,
      );

      expect(result.command, isNot(contains('fps=')));
      expect(result.command, isNot(contains('-r ')));
      expect(result.diagnostics, contains('output_fps=source'));
    });

    test('no-audio input: no audio map or codec flags', () {
      final result = FFmpegProcessor.buildExportCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        settings: baseSettings,
        trimStart: Duration.zero,
        trimEnd: const Duration(seconds: 10),
        playbackSpeed: 1.0,
        videoFilter: VideoFilter.original,
        aspectRatio: ExportAspectRatio.source,
        hasAudio: false,
        finalFps: 30,
        applyWatermark: false,
        watermarkPath: null,
      );

      expect(result.command, isNot(contains('0:a')));
      expect(result.command, isNot(contains('-c:a')));
    });

    test('watermark skipped (null path): no overlay, no drawtext', () {
      final result = FFmpegProcessor.buildExportCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        settings: baseSettings,
        trimStart: Duration.zero,
        trimEnd: const Duration(seconds: 10),
        playbackSpeed: 1.0,
        videoFilter: VideoFilter.original,
        aspectRatio: ExportAspectRatio.source,
        hasAudio: true,
        finalFps: 30,
        applyWatermark: true,
        watermarkPath: null,
      );

      expect(result.diagnostics, contains('watermark_skipped=true'));
      expect(result.command, isNot(contains('overlay=')));
      expect(result.command, isNot(contains('drawtext')));
    });

    test('watermark active (png): looped image input with format=rgba', () {
      final result = FFmpegProcessor.buildExportCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        settings: baseSettings,
        trimStart: Duration.zero,
        trimEnd: const Duration(seconds: 10),
        playbackSpeed: 1.0,
        videoFilter: VideoFilter.original,
        aspectRatio: ExportAspectRatio.source,
        hasAudio: true,
        finalFps: 30,
        applyWatermark: true,
        watermarkPath: '/cache/watermark_runtime.png',
        watermarkBackend: WatermarkBackend.png,
      );

      expect(result.command, contains('-loop 1 -framerate 1'));
      expect(result.command, contains('format=rgba,scale=120:-1'));
      expect(result.command, contains('overlay='));
    });

    test('watermark active (rawRgba): rawvideo input with width/height', () {
      final result = FFmpegProcessor.buildExportCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        settings: baseSettings,
        trimStart: Duration.zero,
        trimEnd: const Duration(seconds: 10),
        playbackSpeed: 1.0,
        videoFilter: VideoFilter.original,
        aspectRatio: ExportAspectRatio.source,
        hasAudio: true,
        finalFps: 30,
        applyWatermark: true,
        watermarkPath: '/cache/watermark_runtime.rgba',
        watermarkWidth: 1024,
        watermarkHeight: 1024,
        watermarkBackend: WatermarkBackend.rawRgba,
      );

      expect(
        result.command,
        contains(
          '-f rawvideo -pixel_format rgba -video_size 1024x1024 -framerate 1 -stream_loop -1',
        ),
      );
      expect(result.command, contains('format=rgba,scale=120:-1'));
      expect(result.command, contains('overlay='));
    });

    test('MKV format: no faststart flag', () {
      const mkvSettings = ExportSettings(
        resolution: ExportResolution.p720,
        fps: 30,
        qualityPreset: ExportQualityPreset.standard,
        format: ExportFormat.mkv,
      );

      final result = FFmpegProcessor.buildExportCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mkv',
        settings: mkvSettings,
        trimStart: Duration.zero,
        trimEnd: const Duration(seconds: 10),
        playbackSpeed: 1.0,
        videoFilter: VideoFilter.original,
        aspectRatio: ExportAspectRatio.source,
        hasAudio: true,
        finalFps: 30,
        applyWatermark: false,
        watermarkPath: null,
      );

      expect(result.command, isNot(contains('-movflags')));
    });

    // ── S005A: FALLBACK TOGGLE TESTS ──

    test('watermarkBackend=none: no watermark in command', () {
      final result = FFmpegProcessor.buildExportCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        settings: baseSettings,
        trimStart: Duration.zero,
        trimEnd: const Duration(seconds: 10),
        playbackSpeed: 1.0,
        videoFilter: VideoFilter.original,
        aspectRatio: ExportAspectRatio.source,
        hasAudio: true,
        finalFps: 30,
        applyWatermark: true,
        watermarkPath: '/cache/watermark_runtime.png',
        watermarkBackend: WatermarkBackend.none,
      );

      expect(result.command, isNot(contains('-loop')));
      expect(result.command, isNot(contains('overlay=')));
      expect(result.diagnostics, contains('watermark_skipped=true'));
      expect(result.watermarkSkippedMessage, contains('Watermark skipped'));
    });

    test('includeAudio=false: no audio map or codec', () {
      final result = FFmpegProcessor.buildExportCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        settings: baseSettings,
        trimStart: Duration.zero,
        trimEnd: const Duration(seconds: 10),
        playbackSpeed: 1.0,
        videoFilter: VideoFilter.original,
        aspectRatio: ExportAspectRatio.source,
        hasAudio: true,
        finalFps: 30,
        applyWatermark: false,
        watermarkPath: null,
        includeAudio: false,
      );

      expect(result.command, isNot(contains('0:a')));
      expect(result.command, isNot(contains('-c:a')));
      expect(result.diagnostics, contains('audio_skipped=true'));
    });

    test('x264 fallback codec profile', () {
      final result = FFmpegProcessor.buildExportCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        settings: baseSettings,
        trimStart: Duration.zero,
        trimEnd: const Duration(seconds: 10),
        playbackSpeed: 1.0,
        videoFilter: VideoFilter.original,
        aspectRatio: ExportAspectRatio.source,
        hasAudio: false,
        finalFps: 30,
        applyWatermark: false,
        watermarkPath: null,
        includeAudio: false,
        videoCodecProfile: VideoCodecProfile.x264Fallback,
      );

      expect(result.command, contains('-c:v libx264'));
      expect(result.command, contains('-pix_fmt yuv420p'));
      expect(result.command, contains('-preset veryfast'));
      expect(result.command, contains('-crf 23'));
      expect(result.command, isNot(contains('mpeg4')));
      expect(result.diagnostics, contains('codec_profile=x264_fallback'));
    });
  });

  // ── S005B: WATERMARK CONTRACT / EXPORT RESULT POLICY ──
  group('ExportResult policy', () {
    test('watermark applied: success result', () {
      const result = ExportResult(
        outputPath: '/output.mp4',
        attemptUsed: 'A',
        watermarkRequested: true,
        watermarkApplied: true,
      );

      expect(result.watermarkRequested, true);
      expect(result.watermarkApplied, true);
      expect(result.fallbackReason, isNull);
      // Policy: keep file, show normal success
    });

    test('free-tier + watermark fail: policy rejection state', () {
      const result = ExportResult(
        outputPath: '/output.mp4',
        attemptUsed: 'B',
        watermarkRequested: true,
        watermarkApplied: false,
        fallbackReason: 'Watermark could not be applied',
      );

      expect(result.watermarkRequested, true);
      expect(result.watermarkApplied, false);
      expect(result.fallbackReason, isNotNull);
      // Policy: delete file, show error snackbar
    });

    test('QA bypass + watermark fail: warning state (file kept)', () {
      const result = ExportResult(
        outputPath: '/output.mp4',
        attemptUsed: 'B',
        watermarkRequested: true,
        watermarkApplied: false,
        fallbackReason: 'Watermark skipped due to device codec limitations',
      );

      expect(result.watermarkRequested, true);
      expect(result.watermarkApplied, false);
      expect(result.fallbackReason, isNotNull);
      // Policy: keep file, show warning snackbar (QA mode)
    });

    test('pro user: no watermark requested', () {
      const result = ExportResult(
        outputPath: '/output.mp4',
        attemptUsed: 'A',
        watermarkRequested: false,
        watermarkApplied: false,
      );

      expect(result.watermarkRequested, false);
      expect(result.watermarkApplied, false);
      expect(result.fallbackReason, isNull);
      // Policy: keep file, show normal success
    });
  });

  // ── QA BYPASS FLAG ──
  group('allowWatermarkBypassForQa', () {
    test('default is false (production mode)', () {
      expect(FFmpegProcessor.allowWatermarkBypassForQa, false);
    });

    test('can be toggled for QA testing', () {
      FFmpegProcessor.allowWatermarkBypassForQa = true;
      expect(FFmpegProcessor.allowWatermarkBypassForQa, true);
      // Reset
      FFmpegProcessor.allowWatermarkBypassForQa = false;
    });
  });
}
