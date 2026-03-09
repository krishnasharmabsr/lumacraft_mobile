import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../services/engine/ffmpeg_processor.dart';
import '../../../../services/io/media_io_service.dart';
import '../widgets/trim_controls.dart';

class EditorScreen extends StatefulWidget {
  final String videoPath;

  const EditorScreen({super.key, required this.videoPath});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late VideoPlayerController _controller;
  final FFmpegProcessor _processor = FFmpegProcessor();
  final MediaIoService _ioService = MediaIoService();

  String _currentVideoPath = '';
  Duration _trimStart = Duration.zero;
  Duration _trimEnd = Duration.zero;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _currentVideoPath = widget.videoPath;
    _initializePlayer(_currentVideoPath);
  }

  Future<void> _initializePlayer(String path) async {
    final oldController = _controller;

    _controller = VideoPlayerController.file(File(path));
    await _controller.initialize();

    setState(() {
      _trimStart = Duration.zero;
      _trimEnd = _controller.value.duration;
    });

    _controller.addListener(() {
      if (mounted) setState(() {});
    });

    _controller.play();

    // Dispose old controller if exists to prevent memory leaks
    if (oldController.value.isInitialized) {
      oldController.dispose();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _processTrim() async {
    setState(() => _isProcessing = true);

    try {
      final cacheDir = await getTemporaryDirectory();
      final ext = _currentVideoPath.split('.').last;
      final outputPath = '${cacheDir.path}/trimmed_${const Uuid().v4()}.$ext';

      final trimmedPath = await _processor.processTrim(
        inputPath: _currentVideoPath,
        outputPath: outputPath,
        startTime: _trimStart,
        endTime: _trimEnd,
      );

      _currentVideoPath = trimmedPath;
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('LumaCraft Editor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _isProcessing ? null : _exportVideo,
            tooltip: 'Export to Gallery',
          ),
        ],
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_controller.value.isInitialized)
                  AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  ),
                const SizedBox(height: 16),
                if (_controller.value.isInitialized) ...[
                  Text(
                    '${_formatDuration(_controller.value.position)} / ${_formatDuration(_controller.value.duration)}',
                  ),
                  IconButton(
                    icon: Icon(
                      _controller.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                    ),
                    onPressed: () {
                      setState(() {
                        _controller.value.isPlaying
                            ? _controller.pause()
                            : _controller.play();
                      });
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TrimControls(
                      maxDuration: _controller.value.duration,
                      currentStart: _trimStart,
                      currentEnd: _trimEnd,
                      onStartChanged: (start) {
                        setState(() {
                          _trimStart = start;
                        });
                        _controller.seekTo(start);
                      },
                      onEndChanged: (end) {
                        setState(() {
                          _trimEnd = end;
                        });
                      },
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _processTrim,
                    child: const Text('Process Trim'),
                  ),
                ] else
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
    );
  }
}
