import 'dart:io';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import 'i_media_io_service.dart';
import 'native_video_picker.dart';

class MediaIoService implements IMediaIoService {
  @override
  Future<String?> pickVideoFromGallery() async {
    if (Platform.isAndroid) {
      return NativeVideoPicker.pickVideo();
    }
    // Non-Android: unsupported for now
    return null;
  }

  @override
  Future<String> copyToLocalWorkingDir(String sourcePath) async {
    final cacheDir = await getTemporaryDirectory();
    final ext = sourcePath.split('.').last;
    final String newPath = '${cacheDir.path}/working_${const Uuid().v4()}.$ext';

    final File sourceFile = File(sourcePath);
    await sourceFile.copy(newPath);
    return newPath;
  }

  @override
  Future<bool> saveVideoToGallery(String filePath) async {
    try {
      if (Platform.isAndroid) {
        final storage = await Permission.storage.request();
        final videos = await Permission.videos.request();

        if (!storage.isGranted && !videos.isGranted) {
          if (!await Gal.requestAccess()) return false;
        }
      } else {
        if (!await Gal.hasAccess()) {
          if (!await Gal.requestAccess()) return false;
        }
      }

      await Gal.putVideo(filePath);
      return true;
    } catch (e) {
      return false;
    }
  }
}
