import 'dart:io';
import 'package:path/path.dart' as p;

class FileUtils {
  /// Returns the file size in bytes, or 0 if unavailable.
  static int getFileSize(String path) {
    try {
      return File(path).lengthSync();
    } catch (_) {
      return 0;
    }
  }

  /// Returns the file size as a human-readable string.
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Returns just the filename without extension.
  static String baseName(String path) => p.basenameWithoutExtension(path);

  /// Returns the filename with extension.
  static String fileName(String path) => p.basename(path);

  /// Returns the extension without dot, lowercase.
  static String extension(String path) => p.extension(path).replaceFirst('.', '').toLowerCase();

  /// Generates a trimmed output filename: "name_trimmed.ext"
  static String suggestOutputName(String originalPath, String outputExt) {
    final base = baseName(originalPath);
    return '${base}_trimmed.$outputExt';
  }
}
