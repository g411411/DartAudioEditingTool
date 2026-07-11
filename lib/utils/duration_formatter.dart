class DurationFormatter {
  /// Formats a Duration as mm:ss.ms (e.g., 01:23.456)
  static String format(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final millis = (d.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
    return '$minutes:$seconds.$millis';
  }

  /// Formats as mm:ss only (for shorter display)
  static String formatShort(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Parses a string like "mm:ss.ms" into a Duration. Returns null on parse failure.
  static Duration? tryParse(String s) {
    try {
      final parts = s.split(':');
      if (parts.length != 2) return null;
      final minutes = int.parse(parts[0]);
      final secParts = parts[1].split('.');
      final seconds = int.parse(secParts[0]);
      final millis = secParts.length > 1
          ? int.parse(secParts[1].padRight(3, '0').substring(0, 3))
          : 0;
      return Duration(minutes: minutes, seconds: seconds, milliseconds: millis);
    } catch (_) {
      return null;
    }
  }

  /// Converts Duration to total seconds as a double (for FFmpeg -ss / -to args)
  static String toFFmpegTime(Duration d) {
    final totalSeconds = d.inMilliseconds / 1000.0;
    return totalSeconds.toStringAsFixed(3);
  }
}
