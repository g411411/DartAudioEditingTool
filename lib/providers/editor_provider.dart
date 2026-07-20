import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/audio_file_model.dart';
import '../models/trim_settings_model.dart';
import '../services/audio_service.dart';
import '../services/waveform_service.dart';
import '../utils/file_utils.dart';

class EditorProvider extends ChangeNotifier {
  final AudioFileModel audioFile;
  final AudioService _audioService = AudioService();

  // Waveform
  List<double> waveformData = [];
  bool isLoadingWaveform = true;

  // Trim region (as fractions 0.0–1.0)
  double startFraction = 0.0;
  double endFraction = 1.0;

  // Playback
  bool isPlaying = false;
  double playheadFraction = 0.0;
  double volume = 1.0;

  // Effects
  bool fadeIn = false;
  double fadeInDuration = 1.0;
  bool fadeOut = false;
  double fadeOutDuration = 1.0;

  // Format & filename
  OutputFormat outputFormat = OutputFormat.m4a;
  late String outputFileName;

  EditorProvider(this.audioFile) {
    outputFileName = FileUtils.suggestOutputName(
      audioFile.path,
      OutputFormat.m4a.extension,
    );
    _init();
  }

  Future<void> _init() async {
    // Load waveform in background
    waveformData = await WaveformService.extractWaveform(audioFile.path);
    isLoadingWaveform = false;
    notifyListeners();

    // Subscribe to audio position for playhead
    _audioService.positionStream.listen((pos) {
      final total = audioFile.duration;
      if (total.inMilliseconds > 0) {
        final regionStart = startDuration;
        final regionEnd = endDuration;
        final regionLen = regionEnd - regionStart;
        if (regionLen.inMilliseconds > 0) {
          final relPos = pos;
          final globalFrac = (regionStart.inMilliseconds + relPos.inMilliseconds) /
              total.inMilliseconds;
          playheadFraction = globalFrac.clamp(0.0, 1.0);
        } else {
          playheadFraction = startFraction;
        }
      }
      notifyListeners();
    });

    _audioService.playerStateStream.listen((state) {
      isPlaying = state.playing;
      if (state.processingState == ProcessingState.completed) {
        isPlaying = false;
        playheadFraction = startFraction;
      }
      notifyListeners();
    });
  }

  Duration get startDuration =>
      Duration(milliseconds: (startFraction * audioFile.duration.inMilliseconds).round());

  Duration get endDuration =>
      Duration(milliseconds: (endFraction * audioFile.duration.inMilliseconds).round());

  Duration get selectionDuration => endDuration - startDuration;

  void setStartFraction(double value) {
    startFraction = value.clamp(0.0, endFraction - 0.001);
    notifyListeners();
  }

  void setEndFraction(double value) {
    endFraction = value.clamp(startFraction + 0.001, 1.0);
    notifyListeners();
  }

  void setStartDuration(Duration d) {
    final total = audioFile.duration.inMilliseconds;
    if (total > 0) {
      startFraction = (d.inMilliseconds / total).clamp(0.0, endFraction - 0.001);
    }
    notifyListeners();
  }

  void setEndDuration(Duration d) {
    final total = audioFile.duration.inMilliseconds;
    if (total > 0) {
      endFraction = (d.inMilliseconds / total).clamp(startFraction + 0.001, 1.0);
    }
    notifyListeners();
  }

  void setFadeIn(bool val) { fadeIn = val; notifyListeners(); }
  void setFadeInDuration(double val) { fadeInDuration = val; notifyListeners(); }
  void setFadeOut(bool val) { fadeOut = val; notifyListeners(); }
  void setFadeOutDuration(double val) { fadeOutDuration = val; notifyListeners(); }

  void setOutputFormat(OutputFormat fmt) {
    outputFormat = fmt;
    final base = FileUtils.baseName(audioFile.path);
    outputFileName = '${base}_trimmed.${fmt.extension}';
    notifyListeners();
  }

  void setOutputFileName(String name) {
    outputFileName = name;
    notifyListeners();
  }

  bool get hasUnsavedChanges =>
      startFraction != 0.0 || endFraction != 1.0 || fadeIn || fadeOut;

  // M4R 40-second limit enforcement
  bool get isM4rTooLong =>
      outputFormat == OutputFormat.m4r && selectionDuration.inSeconds > 40;

  Future<void> togglePlayPause() async {
    if (isPlaying) {
      await _audioService.pause();
    } else {
      await _audioService.loadRegion(audioFile.path, startDuration, endDuration);
      await _audioService.setVolume(volume);
      await _audioService.play();
    }
  }

  Future<void> stopPlayback() async {
    await _audioService.stop();
    playheadFraction = startFraction;
    notifyListeners();
  }

  /// Stops playback and sets end trim point to the current playhead position.
  Future<void> stopAndSetEnd() async {
    if (isPlaying) {
      final currentFrac = playheadFraction;
      await _audioService.stop();
      isPlaying = false;
      // Set end to current position (must be after start)
      endFraction = currentFrac.clamp(startFraction + 0.001, 1.0);
      playheadFraction = startFraction;
      notifyListeners();
    } else {
      await stopPlayback();
    }
  }

  void setVolume(double val) {
    volume = val.clamp(0.0, 1.0);
    _audioService.setVolume(volume);
    notifyListeners();
  }

  TrimSettings buildTrimSettings() {
    return TrimSettings(
      start: startDuration,
      end: endDuration,
      fadeIn: fadeIn,
      fadeInDuration: fadeInDuration,
      fadeOut: fadeOut,
      fadeOutDuration: fadeOutDuration,
      outputFormat: outputFormat,
      outputFileName: outputFileName,
    );
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }
}
