import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
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
      return await FilePicker.saveFile(
        dialogTitle: 'Save audio file',
        fileName: result.outputFileName,
        type: FileType.custom,
        allowedExtensions: [ext],
        bytes: bytes,
      );
    }
    try {
      final String? selectedPath = await FilePicker.saveFile(
        dialogTitle: 'Select location to save trimmed audio',
        fileName: result.outputFileName,
        initialDirectory: downloadsDir,
        type: FileType.custom,
        allowedExtensions: [ext],
        bytes: bytes,
      );

      if (selectedPath != null && selectedPath.isNotEmpty) {
        final targetFile = File(selectedPath);
        // If file_picker did not automatically write bytes natively (e.g. desktop platforms)
        if (!targetFile.existsSync() || targetFile.lengthSync() == 0) {
          try {
            await targetFile.writeAsBytes(bytes, flush: true);
          } catch (_) {
            // Ignore POSIX permission errors if Scoped Storage/SAF already saved the file bytes
          }
        }
        return selectedPath;
      }
    } catch (e) {
      // Fallback: ask for folder path
      try {
        final String? selectedDirectory = await FilePicker.getDirectoryPath(
          dialogTitle: 'Select folder to save audio',
          initialDirectory: downloadsDir,
        );
        if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
          final targetPath = p.join(selectedDirectory, result.outputFileName);
          final targetFile = File(targetPath);
          await targetFile.writeAsBytes(bytes, flush: true);
          return targetPath;
        }
      } catch (fallbackError) {
        throw Exception(
            'Cannot write to selected location ($fallbackError). Please select the Downloads folder or a supported directory.');
      }
    }
    return null;
  }
}
