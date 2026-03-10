import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft_mobile/core/models/export_settings.dart';
import 'package:lumacraft_mobile/services/engine/ffmpeg_processor.dart';

void main() {
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

  group('buildExportCommand', () {
    const baseSettings = ExportSettings(
      resolution: ExportResolution.p720,
      fps: 30,
      quality: 65,
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
        aspectRatio: ExportAspectRatio.source,
        hasAudio: true,
        finalFps: 30,
        applyWatermark: false,
        watermarkPath: null,
      );

      // Should contain bare 0:a:0 (no brackets)
      expect(result.command, contains('0:a:0'));
      // Should NOT contain [0:a:0] as a -map argument
      expect(result.command, isNot(contains('-map "[0:a:0]"')));
      // Should contain audio codec
      expect(result.command, contains('-c:a aac'));
      // Should contain faststart for MP4
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
        aspectRatio: ExportAspectRatio.source,
        hasAudio: true,
        finalFps: 30,
        applyWatermark: false,
        watermarkPath: null,
      );

      // Should contain chained atempo
      expect(result.command, contains('atempo=2.0,atempo=2.0'));
      // Should map audio via filter label
      expect(result.command, contains('"[a_speed]"'));
    });

    test('no-audio input: no audio map or codec flags', () {
      final result = FFmpegProcessor.buildExportCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        settings: baseSettings,
        trimStart: Duration.zero,
        trimEnd: const Duration(seconds: 10),
        playbackSpeed: 1.0,
        aspectRatio: ExportAspectRatio.source,
        hasAudio: false,
        finalFps: 30,
        applyWatermark: false,
        watermarkPath: null,
      );

      // Should NOT contain any audio mapping
      expect(result.command, isNot(contains('0:a')));
      expect(result.command, isNot(contains('-c:a')));
      expect(result.command, isNot(contains('-b:a')));
    });

    test('watermark skipped: no watermark inputs in command', () {
      final result = FFmpegProcessor.buildExportCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        settings: baseSettings,
        trimStart: Duration.zero,
        trimEnd: const Duration(seconds: 10),
        playbackSpeed: 1.0,
        aspectRatio: ExportAspectRatio.source,
        hasAudio: true,
        finalFps: 30,
        applyWatermark: true,
        watermarkPath: null, // watermark path failed
      );

      // Diagnostics should indicate skipped
      expect(result.diagnostics, contains('watermark_skipped=true'));
      // Should NOT contain overlay filter
      expect(result.command, isNot(contains('overlay=')));
      // Should NOT contain -loop for watermark
      expect(result.command, isNot(contains('-loop')));
      // Should NOT contain drawtext
      expect(result.command, isNot(contains('drawtext')));
      // Command should still be valid with video and audio
      expect(result.command, contains('-c:v mpeg4'));
      expect(result.command, contains('-c:a aac'));
    });

    test('watermark active: looped image input with format=rgba', () {
      final result = FFmpegProcessor.buildExportCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        settings: baseSettings,
        trimStart: Duration.zero,
        trimEnd: const Duration(seconds: 10),
        playbackSpeed: 1.0,
        aspectRatio: ExportAspectRatio.source,
        hasAudio: true,
        finalFps: 30,
        applyWatermark: true,
        watermarkPath: '/cache/watermark_runtime.png',
      );

      // Should contain looped image input
      expect(result.command, contains('-loop 1 -framerate 1'));
      // Should contain format=rgba in filter
      expect(result.command, contains('format=rgba,scale=120:-1'));
      // Should contain overlay
      expect(result.command, contains('overlay='));
      // Should NOT contain drawtext
      expect(result.command, isNot(contains('drawtext')));
    });

    test('MKV format: no faststart flag', () {
      const mkvSettings = ExportSettings(
        resolution: ExportResolution.p720,
        fps: 30,
        quality: 65,
        format: ExportFormat.mkv,
      );

      final result = FFmpegProcessor.buildExportCommand(
        inputPath: '/input.mp4',
        outputPath: '/output.mkv',
        settings: mkvSettings,
        trimStart: Duration.zero,
        trimEnd: const Duration(seconds: 10),
        playbackSpeed: 1.0,
        aspectRatio: ExportAspectRatio.source,
        hasAudio: true,
        finalFps: 30,
        applyWatermark: false,
        watermarkPath: null,
      );

      // Should NOT contain faststart for MKV
      expect(result.command, isNot(contains('-movflags')));
    });
  });
}
