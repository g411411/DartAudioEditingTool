import 'dart:io';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'export_service.dart';

class ConcatenationService {
  static Future<ExportResult> concatenateToWav({
    required String firstInputPath,
    required String secondInputPath,
    void Function(double progress)? onProgress,
  }) async {
    final firstFile = File(firstInputPath);
    final secondFile = File(secondInputPath);

    if (!firstFile.existsSync()) {
      throw Exception('First audio file was not found.');
    }
    if (!secondFile.existsSync()) {
      throw Exception('Second audio file was not found.');
    }

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputFileName = 'concatenated_$timestamp.wav';
    final outputPath = p.join(tempDir.path, outputFileName);

    onProgress?.call(0.1);

    final command =
        '-y -i "${_escapePath(firstInputPath)}" -i "${_escapePath(secondInputPath)}" '
        '-filter_complex "[0:a]aresample=44100,aformat=sample_fmts=s16:channel_layouts=stereo[a0];'
        '[1:a]aresample=44100,aformat=sample_fmts=s16:channel_layouts=stereo[a1];'
        '[a0][a1]concat=n=2:v=0:a=1[outa]" '
        '-map "[outa]" -c:a pcm_s16le "${_escapePath(outputPath)}"';

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    onProgress?.call(0.9);

    if (!ReturnCode.isSuccess(returnCode)) {
      final logs = await session.getAllLogsAsString();
      throw Exception('Audio concatenation failed: $logs');
    }

    final outputFile = File(outputPath);
    if (!outputFile.existsSync()) {
      throw Exception('Concatenated output file was not created.');
    }

    onProgress?.call(1.0);

    return ExportResult(
      outputPath: outputPath,
      outputFileName: outputFileName,
      outputDuration: Duration.zero,
      outputSizeBytes: outputFile.lengthSync(),
    );
  }

  static String _escapePath(String path) => path.replaceAll('"', '\\"');
}
