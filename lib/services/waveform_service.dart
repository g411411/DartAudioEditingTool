import 'dart:typed_data';
import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class WaveformService {
  /// Extracts waveform amplitude data from an audio file using FFmpeg.
  /// Returns a list of [sampleCount] normalized amplitude values in [0.0, 1.0].
  static Future<List<double>> extractWaveform(
    String inputPath, {
    int sampleCount = 800,
    int sampleRate = 6000,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final pcmPath = p.join(tempDir.path, 'waveform_${DateTime.now().millisecondsSinceEpoch}.pcm');

      // Convert audio to raw 16-bit PCM mono at a low sample rate for waveform
      final command =
          '-y -i "$inputPath" -ac 1 -ar $sampleRate -f s16le "$pcmPath"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (returnCode == null || !returnCode.isValueSuccess()) {
        // Return flat waveform on failure
        return List.filled(sampleCount, 0.1);
      }

      final pcmFile = File(pcmPath);
      if (!pcmFile.existsSync()) return List.filled(sampleCount, 0.1);

      final bytes = await pcmFile.readAsBytes();
      final samples = _parsePcm16(bytes);

      // Clean up temp file
      try { pcmFile.deleteSync(); } catch (_) {}

      if (samples.isEmpty) return List.filled(sampleCount, 0.1);

      return _downsample(samples, sampleCount);
    } catch (e) {
      return List.filled(sampleCount, 0.1);
    }
  }

  /// Parses raw 16-bit little-endian PCM bytes into normalized doubles.
  static List<double> _parsePcm16(Uint8List bytes) {
    if (bytes.length < 2) return [];
    final int sampleCount = bytes.length ~/ 2;
    final result = <double>[];
    final byteData = ByteData.sublistView(bytes);
    for (int i = 0; i < sampleCount; i++) {
      final sample = byteData.getInt16(i * 2, Endian.little);
      result.add(sample.abs() / 32768.0);
    }
    return result;
  }

  /// Downsamples a large list of samples to [targetCount] values by averaging chunks.
  static List<double> _downsample(List<double> samples, int targetCount) {
    if (samples.length <= targetCount) {
      // Pad with zeros
      return [...samples, ...List.filled(targetCount - samples.length, 0.0)];
    }
    final chunkSize = samples.length / targetCount;
    final result = <double>[];
    for (int i = 0; i < targetCount; i++) {
      final start = (i * chunkSize).round();
      final end = ((i + 1) * chunkSize).round().clamp(0, samples.length);
      if (start >= end) {
        result.add(0.0);
        continue;
      }
      double sum = 0;
      for (int j = start; j < end; j++) {
        sum += samples[j];
      }
      result.add(sum / (end - start));
    }
    return result;
  }
}
