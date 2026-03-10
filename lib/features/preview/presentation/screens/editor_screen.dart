import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:uuid/uuid.dart';

import '../../../../services/engine/ffmpeg_processor.dart';
import '../../../../services/io/media_io_service.dart';
import '../../../../services/io/native_video_picker.dart';
import '../widgets/trim_controls.dart';

class EditorScreen extends StatefulWidget {
  final String videoPath;

  const EditorScreen({super.key, required this.videoPath});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  VideoPlayerController? _controller;
  final FFmpegProcessor _processor = FFmpegProcessor();
  final MediaIoService _ioService = MediaIoService();

  String _currentVideoPath = '';
  Duration _trimStart = Duration.zero;
  Duration _trimEnd = Duration.zero;
  bool _isProcessing = false;
  bool _isPreviewingTrim = false;
  bool _hasEdits = false;
  VoidCallback? _previewListener;

  @override
  void initState() {
    super.initState();
    _currentVideoPath = widget.videoPath;
    _initializePlayer(_currentVideoPath);
  }

  Future<void> _initializePlayer(String path) async {
    final oldController = _controller;

    final newController = VideoPlayerController.file(File(path));
    await newController.initialize();

    if (mounted) {
      setState(() {
        _controller = newController;
        _trimStart = Duration.zero;
        _trimEnd = newController.value.duration;
        _isPreviewingTrim = false;
        // _hasEdits intentionally NOT reset here — only reset on fresh import
      });
    }

    newController.addListener(() {
      if (mounted) setState(() {});
    });

    newController.play();
    oldController?.dispose();
  }

  @override
  void dispose() {
    _removePreviewListener();
    _controller?.dispose();
    super.dispose();
  }

  void _removePreviewListener() {
    if (_previewListener != null && _controller != null) {
      _controller!.removeListener(_previewListener!);
      _previewListener = null;
    }
    _isPreviewingTrim = false;
  }

  void _previewTrim() {
    final ctrl = _controller;
    if (ctrl == null) return;

    // Clean up any existing preview listener
    _removePreviewListener();

    // Seek to trim start and play
    ctrl.seekTo(_trimStart);
    ctrl.play();
    _isPreviewingTrim = true;

    // Create a listener that pauses at _trimEnd
    _previewListener = () {
      if (!mounted || !_isPreviewingTrim) return;
      if (ctrl.value.position >= _trimEnd) {
        ctrl.pause();
        _removePreviewListener();
        if (mounted) setState(() {});
      }
    };
    ctrl.addListener(_previewListener!);
    setState(() {});
  }

  Future<void> _processTrim() async {
    // Strong validation: minimum 300ms trim range
    final rangeMs = (_trimEnd - _trimStart).inMilliseconds;
    if (rangeMs < 300) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Invalid trim range. End must be greater than start.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final cachePath = await NativeVideoPicker.getCachePath();
      final ext = _currentVideoPath.split('.').last;
      final outputPath = '$cachePath/trimmed_${const Uuid().v4()}.$ext';

      final trimmedPath = await _processor.processTrim(
        inputPath: _currentVideoPath,
        outputPath: outputPath,
        startTime: _trimStart,
        endTime: _trimEnd,
      );

      _currentVideoPath = trimmedPath;
      _hasEdits = true;
      await _initializePlayer(trimmedPath);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Trim successful')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Trim error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _exportVideo() async {
    // Guard: block export if no edits have been made
    if (!_hasEdits) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No edits to export. Trim first.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final success = await _ioService.saveVideoToGallery(_currentVideoPath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Exported to gallery!' : 'Export failed.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;
    final isReady = ctrl != null && ctrl.value.isInitialized;

    return Scaffold(
      appBar: AppBar(title: const Text('LumaCraft Editor')),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  // --- Video preview area (bounded) ---
                  if (isReady)
                    Flexible(
                      flex: 3,
                      child: Container(
                        color: Colors.black,
                        alignment: Alignment.center,
                        child: AspectRatio(
                          aspectRatio: ctrl.value.aspectRatio,
                          child: VideoPlayer(ctrl),
                        ),
                      ),
                    )
                  else
                    const Expanded(
                      flex: 3,
                      child: Center(child: CircularProgressIndicator()),
                    ),

                  // --- Controls section (scrollable) ---
                  if (isReady)
                    Expanded(
                      flex: 4,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // -- Playback section --
                            _sectionHeader('Playback'),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${_formatDuration(ctrl.value.position)} / ${_formatDuration(ctrl.value.duration)}',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(width: 16),
                                IconButton.filled(
                                  icon: Icon(
                                    ctrl.value.isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                  ),
                                  onPressed: () {
                                    _removePreviewListener();
                                    setState(() {
                                      ctrl.value.isPlaying
                                          ? ctrl.pause()
                                          : ctrl.play();
                                    });
                                  },
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),
                            const Divider(),

                            // -- Trim Range section --
                            _sectionHeader('Trim Range'),
                            const SizedBox(height: 4),
                            TrimControls(
                              maxDuration: ctrl.value.duration,
                              currentStart: _trimStart,
                              currentEnd: _trimEnd,
                              onStartChanged: (start) {
                                setState(() => _trimStart = start);
                                ctrl.seekTo(start);
                              },
                              onEndChanged: (end) {
                                setState(() => _trimEnd = end);
                              },
                            ),

                            const SizedBox(height: 16),
                            const Divider(),

                            // -- Actions section --
                            _sectionHeader('Actions'),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _previewTrim,
                                  icon: const Icon(Icons.preview),
                                  label: Text(
                                    _isPreviewingTrim
                                        ? 'Previewing...'
                                        : 'Preview Trim',
                                  ),
                                ),
                                FilledButton.icon(
                                  onPressed: _processTrim,
                                  icon: const Icon(Icons.content_cut),
                                  label: const Text('Process Trim'),
                                ),
                                FilledButton.icon(
                                  onPressed: _hasEdits ? _exportVideo : null,
                                  icon: const Icon(Icons.save_alt),
                                  label: const Text('Export'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.grey,
        letterSpacing: 0.5,
      ),
    );
  }
}
