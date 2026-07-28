import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/trim_settings_model.dart';
import '../utils/duration_formatter.dart';

class ExportResult {
  final String outputPath;
  final String outputFileName;
  final Duration outputDuration;
  final int outputSizeBytes;

  const ExportResult({
    required this.outputPath,
    required this.outputFileName,
    required this.outputDuration,
    required this.outputSizeBytes,
  });
}

class ExportService {
  /// Trims and encodes the audio file according to [settings].
  /// Calls [onProgress] with a value 0.0–1.0 as processing progresses.
  static Future<ExportResult> export({
    required String inputPath,
    required TrimSettings settings,
    void Function(double progress)? onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final outputFileName = settings.outputFileName;
    final outputPath = p.join(tempDir.path, outputFileName);

    final startArg = DurationFormatter.toFFmpegTime(settings.start);
    final endArg = DurationFormatter.toFFmpegTime(settings.end);
    final codec = settings.outputFormat.ffmpegCodec;

    // Build the full FFmpeg command
    String command;
    if (settings.outputFormat == OutputFormat.wav) {
      command =
          '-y -i "$inputPath" -ss $startArg -to $endArg -c:a $codec -ar 44100 "$outputPath"';
    } else {
      command =
          '-y -i "$inputPath" -ss $startArg -to $endArg -c:a $codec -b:a 192k "$outputPath"';
    }

    // Report 10% progress while FFmpeg is running
    onProgress?.call(0.1);

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    onProgress?.call(0.9);

    if (!ReturnCode.isSuccess(returnCode)) {
      final logs = await session.getAllLogsAsString();
      throw Exception('FFmpeg export failed: $logs');
    }

    final outputFile = File(outputPath);
    final outputSize = outputFile.existsSync() ? outputFile.lengthSync() : 0;

    onProgress?.call(1.0);

    return ExportResult(
      outputPath: outputPath,
      outputFileName: outputFileName,
      outputDuration: settings.selectionDuration,
      outputSizeBytes: outputSize,
    );
  }

  /// Returns default Downloads directory path across platforms.
  static Future<String?> getDownloadsDirectoryPath() async {
    if (kIsWeb) return null;
    if (Platform.isAndroid) {
      final androidDownloadDir = Directory('/storage/emulated/0/Download');
      if (androidDownloadDir.existsSync()) {
        return androidDownloadDir.path;
      }
    }
    try {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null && downloadsDir.existsSync()) {
        return downloadsDir.path;
      }
    } catch (_) {}

    try {
      final docsDir = await getApplicationDocumentsDirectory();
      return docsDir.path;
    } catch (_) {}

    return null;
  }

  /// Prompts the user with a system File Picker dialog defaulting to Downloads,
  /// allowing them to pick the save folder and file name.
  static Future<String?> saveWithUserChoice(ExportResult result) async {
    final downloadsDir = await getDownloadsDirectoryPath();
    final ext = p.extension(result.outputFileName).replaceAll('.', '');
    final sourceFile = File(result.outputPath);

    if (!sourceFile.existsSync()) {
      throw Exception('Exported file not found at ${result.outputPath}');
    }

    final Uint8List bytes = await sourceFile.readAsBytes();

    if (Platform.isAndroid) {
      return _saveWavWithAndroidSaf(
        fileName: _ensureExtension(result.outputFileName, ext),
        bytes: bytes,
      );
    }

    if (Platform.isIOS) {
      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Save audio file',
        fileName: _ensureExtension(result.outputFileName, ext),
        type: FileType.custom,
        allowedExtensions: [ext],
        bytes: bytes,
      );
      return savedPath;
    }

    final String? selectedPath = await FilePicker.saveFile(
      dialogTitle: 'Save audio file',
      fileName: result.outputFileName,
      initialDirectory: downloadsDir,
      type: FileType.custom,
      allowedExtensions: [ext],
      bytes: bytes,
    );

    if (selectedPath == null || selectedPath.isEmpty) {
      return null;
    }

    final targetFile = File(selectedPath);
    await targetFile.writeAsBytes(bytes, flush: true);

    final savedSize = await targetFile.length();
    if (savedSize != bytes.length) {
      throw Exception(
        'Saved file size mismatch at $selectedPath. Expected ${bytes.length} bytes, wrote $savedSize bytes.',
      );
    }

    return selectedPath;
  }

  static const MethodChannel _androidSaveChannel =
      MethodChannel('mp3trim/save_audio');

  static Future<String?> _saveWavWithAndroidSaf({
    required String fileName,
    required Uint8List bytes,
  }) {
    return _androidSaveChannel.invokeMethod<String>('saveWav', {
      'fileName': fileName,
      'bytes': bytes,
    });
  }

  static String _ensureExtension(String fileName, String extension) {
    if (extension.isEmpty || p.extension(fileName).isNotEmpty) {
      return fileName;
    }
    return '$fileName.$extension';
  }

  static Future<String> _saveToAndroidDownloads(
    String fileName,
    Uint8List bytes,
  ) async {
    final downloadsDir = Directory('/storage/emulated/0/Download');
    if (!downloadsDir.existsSync()) {
      throw Exception('Downloads folder is not available.');
    }

    final targetPath = _uniquePath(downloadsDir.path, fileName);
    final targetFile = File(targetPath);
    await targetFile.writeAsBytes(bytes, flush: true);

    if (!targetFile.existsSync() || targetFile.lengthSync() == 0) {
      throw Exception('Saved file could not be verified.');
    }

    return targetPath;
  }

  static String _uniquePath(String directory, String fileName) {
    final baseName = p.basenameWithoutExtension(fileName);
    final extension = p.extension(fileName);
    var candidate = p.join(directory, fileName);
    var index = 1;

    while (File(candidate).existsSync()) {
      candidate = p.join(directory, '${baseName}_$index$extension');
      index++;
    }

    return candidate;
  }
}
