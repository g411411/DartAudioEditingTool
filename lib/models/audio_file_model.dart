class AudioFileModel {
  final String path;
  final String name;
  final Duration duration;
  final int sizeBytes;

  const AudioFileModel({
    required this.path,
    required this.name,
    required this.duration,
    required this.sizeBytes,
  });

  String get sizeFormatted {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
