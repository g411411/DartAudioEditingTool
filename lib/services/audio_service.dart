import 'package:just_audio/just_audio.dart';

class AudioService {
  final AudioPlayer _player = AudioPlayer();

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  bool get isPlaying => _player.playing;
  Duration get currentPosition => _player.position;

  /// Loads the audio file and sets up a clipping source to play the selected region.
  Future<void> loadRegion(String filePath, Duration start, Duration end) async {
    try {
      final source = ClippingAudioSource(
        child: AudioSource.file(filePath),
        start: start,
        end: end,
      );
      await _player.setAudioSource(source);
    } catch (e) {
      // Fallback: try loading without clipping
      try {
        await _player.setFilePath(filePath);
        await _player.seek(start);
      } catch (_) {}
    }
  }

  /// Plays from the current position.
  Future<void> play() async {
    await _player.play();
  }

  /// Pauses playback.
  Future<void> pause() async {
    await _player.pause();
  }

  /// Stops playback and resets to the beginning of the region.
  Future<void> stop() async {
    await _player.stop();
    await _player.seek(Duration.zero);
  }

  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
  }

  /// Returns the total duration of the loaded source.
  Duration? get totalDuration => _player.duration;

  /// Disposes the player.
  Future<void> dispose() async {
    await _player.dispose();
  }
}
