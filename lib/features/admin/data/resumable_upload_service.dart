import 'package:file_selector/file_selector.dart';
import 'package:tusc/tusc.dart';

class ResumableUploadService {
  const ResumableUploadService();

  Future<void> upload({
    required XFile file,
    required String uploadUrl,
    required void Function(double progress) onProgress,
  }) async {
    final client = TusClient(
      url: uploadUrl,
      file: file,
      chunkSize: 10 * 1024 * 1024,
      metadata: {'name': file.name, 'requiresignedurls': 'true'},
      timeout: const Duration(minutes: 3),
    );
    try {
      await client.startUpload(
        onProgress: (uploaded, total, _) {
          onProgress(total == 0 ? 0 : uploaded / total);
        },
      );
    } finally {
      client.close();
    }
  }
}
