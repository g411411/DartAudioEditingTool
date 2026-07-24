enum OutputFormat { wav, m4a, m4r, aac }

extension OutputFormatExtension on OutputFormat {
  String get label {
    switch (this) {
      case OutputFormat.wav:
        return 'WAV';
      case OutputFormat.m4a:
        return 'M4A';
      case OutputFormat.m4r:
        return 'M4R';
      case OutputFormat.aac:
        return 'AAC';
    }
  }

  String get extension {
    switch (this) {
      case OutputFormat.wav:
        return 'wav';
      case OutputFormat.m4a:
        return 'm4a';
      case OutputFormat.m4r:
        return 'm4r';
      case OutputFormat.aac:
        return 'aac';
    }
  }

  String get ffmpegCodec {
    switch (this) {
      case OutputFormat.wav:
        return 'pcm_s16le';
      case OutputFormat.m4a:
      case OutputFormat.m4r:
      case OutputFormat.aac:
        return 'aac';
    }
  }

  bool get isM4R => this == OutputFormat.m4r;
}

class TrimSettings {
  final Duration start;
  final Duration end;
  final OutputFormat outputFormat;
  final String outputFileName;

  const TrimSettings({
    required this.start,
    required this.end,
    this.outputFormat = OutputFormat.m4a,
    required this.outputFileName,
  });

  Duration get selectionDuration => end - start;

  TrimSettings copyWith({
    Duration? start,
    Duration? end,
    OutputFormat? outputFormat,
    String? outputFileName,
  }) {
    return TrimSettings(
      start: start ?? this.start,
      end: end ?? this.end,
      outputFormat: outputFormat ?? this.outputFormat,
      outputFileName: outputFileName ?? this.outputFileName,
    );
  }
}
