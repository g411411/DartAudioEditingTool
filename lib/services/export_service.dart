import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
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

    // Build FFmpeg filter chain for fades
    final List<String> filters = [];
    final selectionDurationSec =
        settings.selectionDuration.inMilliseconds / 1000.0;

    if (settings.fadeIn) {
      final dur = settings.fadeInDuration.clamp(0.1, selectionDurationSec / 2);
      filters.add('afade=t=in:st=0:d=$dur');
    }

    if (settings.fadeOut) {
      final dur = settings.fadeOutDuration.clamp(0.1, selectionDurationSec / 2);
      final startTime = (selectionDurationSec - dur).clamp(0.0, selectionDurationSec);
      filters.add('afade=t=out:st=${startTime.toStringAsFixed(3)}:d=${dur.toStringAsFixed(3)}');
    }

    final filterArg = filters.isNotEmpty
        ? '-af "${filters.join(',')}"'
        : '';

    final startArg = DurationFormatter.toFFmpegTime(settings.start);
    final endArg = DurationFormatter.toFFmpegTime(settings.end);
    final codec = settings.outputFormat.ffmpegCodec;

    // Build the full FFmpeg command
    String command;
    if (settings.outputFormat == OutputFormat.wav) {
      command =
          '-y -i "$inputPath" -ss $startArg -to $endArg $filterArg -c:a $codec -ar 44100 "$outputPath"';
    } else {
      command =
          '-y -i "$inputPath" -ss $startArg -to $endArg $filterArg -c:a $codec -b:a 192k "$outputPath"';
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

  /// Copies the exported file to the device's Downloads (Android) or Documents (iOS) folder.
  static Future<String> saveToDownloads(ExportResult result) async {
    Directory targetDir;

    if (!kIsWeb && Platform.isAndroid) {
      targetDir = Directory('/storage/emulated/0/Download');
      if (!targetDir.existsSync()) {
        final extDir = await getExternalStorageDirectory();
        targetDir = extDir ?? await getApplicationDocumentsDirectory();
      }
    } else {
      targetDir = await getApplicationDocumentsDirectory();
    }

    final targetPath = p.join(targetDir.path, result.outputFileName);
    await File(result.outputPath).copy(targetPath);
    return targetPath;
  }
}
