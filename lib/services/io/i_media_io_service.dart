abstract class IMediaIoService {
  Future<String?> pickVideoFromGallery();
  Future<String> copyToLocalWorkingDir(String sourcePath);
  Future<bool> saveVideoToGallery(String filePath);
}
