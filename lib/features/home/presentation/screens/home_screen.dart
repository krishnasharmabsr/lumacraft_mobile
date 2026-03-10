import 'package:flutter/material.dart';
import '../../../../services/io/media_io_service.dart';
import '../../../preview/presentation/screens/editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MediaIoService _ioService = MediaIoService();
  bool _isLoading = false;

  Future<void> _importVideo() async {
    setState(() => _isLoading = true);

    try {
      final String? pickedPath = await _ioService.pickVideoFromGallery();

      if (pickedPath != null && mounted) {
        // Copy to working directory
        final localPath = await _ioService.copyToLocalWorkingDir(pickedPath);

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditorScreen(videoPath: localPath),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LumaCraft Studio')),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : ElevatedButton.icon(
                icon: const Icon(Icons.video_library),
                label: const Text('Import Video'),
                onPressed: _importVideo,
              ),
      ),
    );
  }
}
