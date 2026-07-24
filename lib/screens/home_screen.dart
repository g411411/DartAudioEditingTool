import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../models/audio_file_model.dart';
import '../models/trim_settings_model.dart';
import '../providers/editor_provider.dart';
import '../services/concatenation_service.dart';
import '../services/export_service.dart';
import '../utils/file_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AudioFileModel? _audioFile;
  bool _isLoading = false;
  bool _isExporting = false;
  bool _isConcatenating = false;
  double _exportProgress = 0;
  double _concatProgress = 0;
  String? _message;
  String? _concatFirstPath;
  String? _concatSecondPath;
  String? _concatMessage;

  Future<bool> _requestAudioPermission() async {
    if (kIsWeb || !Platform.isAndroid) return true;

    final audioStatus = await Permission.audio.request();
    if (audioStatus.isGranted) return true;

    final storageStatus = await Permission.storage.request();
    return storageStatus.isGranted;
  }

  Future<String?> _pickAudioPath() async {
    if (!await _requestAudioPermission()) {
      setState(() => _message = 'Storage permission is required.');
      return null;
    }

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'aac'],
      withData: false,
    );

    if (result == null || result.files.isEmpty) return null;
    return result.files.first.path;
  }

  Future<void> _selectTrimFile() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final path = await _pickAudioPath();
      if (path == null) return;

      Duration duration = Duration.zero;
      final player = AudioPlayer();
      try {
        duration = await player.setFilePath(path) ?? Duration.zero;
      } finally {
        await player.dispose();
      }

      setState(() {
        _audioFile = AudioFileModel(
          path: path,
          name: FileUtils.fileName(path),
          duration: duration,
          sizeBytes: FileUtils.getFileSize(path),
        );
        _message = 'Loaded ${FileUtils.fileName(path)}';
      });
    } catch (e) {
      setState(() => _message = 'Load failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveTrimmedWav(EditorProvider provider) async {
    final file = _audioFile;
    if (file == null) return;

    setState(() {
      _isExporting = true;
      _exportProgress = 0;
      _message = 'Preparing WAV...';
    });

    try {
      final result = await ExportService.export(
        inputPath: file.path,
        settings: TrimSettings(
          start: provider.startDuration,
          end: provider.endDuration,
          outputFormat: OutputFormat.wav,
          outputFileName: '${FileUtils.baseName(file.path)}_trimmed.wav',
        ),
        onProgress: (progress) {
          if (mounted) setState(() => _exportProgress = progress);
        },
      );

      if (!mounted) return;
      setState(() => _message = 'Choose save location...');
      final savedPath = await ExportService.saveWithUserChoice(result);
      if (!mounted) return;
      setState(
          () => _message = savedPath == null ? 'Save canceled.' : 'Saved WAV');
    } catch (e) {
      if (mounted) setState(() => _message = 'Save failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _exportProgress = 0;
        });
      }
    }
  }

  Future<void> _pickConcatenationFile({required bool first}) async {
    setState(() {
      _concatMessage = null;
      _message = null;
    });

    final path = await _pickAudioPath();
    if (path == null) return;

    setState(() {
      if (first) {
        _concatFirstPath = path;
      } else {
        _concatSecondPath = path;
      }
    });
  }

  Future<void> _concatenateAndSave() async {
    final firstPath = _concatFirstPath;
    final secondPath = _concatSecondPath;

    if (firstPath == null || secondPath == null) {
      setState(() => _concatMessage = 'Choose both files.');
      return;
    }

    setState(() {
      _isConcatenating = true;
      _concatProgress = 0;
      _concatMessage = 'Concatenating...';
    });

    try {
      final result = await ConcatenationService.concatenateToWav(
        firstInputPath: firstPath,
        secondInputPath: secondPath,
        onProgress: (progress) {
          if (mounted) setState(() => _concatProgress = progress);
        },
      );

      if (!mounted) return;
      setState(() => _concatMessage = 'Choose save location...');
      final savedPath = await ExportService.saveWithUserChoice(result);
      if (!mounted) return;
      setState(() => _concatMessage =
          savedPath == null ? 'Save canceled.' : 'Saved concatenated WAV');
    } catch (e) {
      if (mounted) setState(() => _concatMessage = 'Concat failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isConcatenating = false;
          _concatProgress = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _audioFile == null
        ? _buildBody(null)
        : ChangeNotifierProvider(
            key: ValueKey(_audioFile!.path),
            create: (_) => EditorProvider(_audioFile!),
            child: Consumer<EditorProvider>(
              builder: (_, provider, __) => _buildBody(provider),
            ),
          );

    return Scaffold(
      backgroundColor: const Color(0xFF0A1220),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: 390,
                  height: 790,
                  child: content,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(EditorProvider? provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Audio trimmer',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF68A7FF),
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            flex: 57,
            child: _buildTrimPanel(provider),
          ),
          const SizedBox(height: 10),
          Expanded(
            flex: 35,
            child: _buildConcatPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildTrimPanel(EditorProvider? provider) {
    final hasFile = provider != null && _audioFile != null;
    final start = hasFile ? provider.startDuration : Duration.zero;
    final end = hasFile ? provider.endDuration : Duration.zero;
    final total = _audioFile?.duration ?? Duration.zero;
    final displayEnd = end == Duration.zero ? total : end;

    return _GlassPanel(
      color: const Color(0xFF132B4A),
      borderColor: const Color(0xFF255C93),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeader(
            icon: Icons.content_cut_rounded,
            title: 'Trim fragment',
            color: const Color(0xFF68A7FF),
          ),
          const SizedBox(height: 8),
          _CompactFilePickerRow(
            label: 'Source',
            fileName: _audioFile?.name,
            buttonText: _isLoading ? 'Loading' : 'Select',
            color: const Color(0xFF2E7BFF),
            onPressed: _isLoading ? null : _selectTrimFile,
          ),
          const SizedBox(height: 8),
          _StatusLine(text: _message ?? 'Select a file to trim.'),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(_formatMs(start), style: _monoStyle(12)),
              const Spacer(),
              Text(_formatMs(displayEnd), style: _monoStyle(12)),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              activeTrackColor: const Color(0xFF64C59D),
              inactiveTrackColor: const Color(0xFF30445D),
              thumbColor: Colors.white,
              overlayShape: SliderComponentShape.noOverlay,
              rangeThumbShape:
                  const RoundRangeSliderThumbShape(enabledThumbRadius: 5),
            ),
            child: RangeSlider(
              values: RangeValues(hasFile ? provider.startFraction : 0,
                  hasFile ? provider.endFraction : 1),
              min: 0,
              max: 1,
              onChanged: hasFile
                  ? (values) {
                      provider.setStartFraction(values.start);
                      provider.setEndFraction(values.end);
                    }
                  : null,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: provider?.isPlaying == true
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  label: 'Play',
                  color: const Color(0xFF2E7BFF),
                  onPressed: hasFile ? provider.togglePlayPause : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.stop_rounded,
                  label: 'Stop',
                  color: const Color(0xFFE52A2A),
                  onPressed: hasFile ? provider.stopPlayback : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.restart_alt_rounded,
                  label: 'Restart',
                  color: const Color(0xFF637184),
                  onPressed: hasFile ? provider.stopPlayback : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _TimeTile(
                  label: 'Start',
                  value: start,
                  buttonText: 'Set',
                  color: const Color(0xFF6FAFFF),
                  onPressed: hasFile
                      ? () =>
                          provider.setStartFraction(provider.playheadFraction)
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TimeTile(
                  label: 'End',
                  value: displayEnd,
                  buttonText: 'Set',
                  color: const Color(0xFF9C6BFF),
                  onPressed: hasFile
                      ? () => provider.setEndFraction(provider.playheadFraction)
                      : null,
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.volume_up_rounded,
                  label: 'Preview',
                  color: const Color(0xFF18A957),
                  onPressed: hasFile ? provider.togglePlayPause : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: _isExporting ? null : Icons.save_alt_rounded,
                  label: _isExporting
                      ? '${(_exportProgress * 100).round()}%'
                      : 'Save WAV',
                  color: const Color(0xFF2E7BFF),
                  onPressed: hasFile && !_isExporting
                      ? () => _saveTrimmedWav(provider)
                      : null,
                  busy: _isExporting,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConcatPanel() {
    return _GlassPanel(
      color: const Color(0xFF0F5F32),
      borderColor: const Color(0xFF25A75A),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeader(
            icon: Icons.merge_type_rounded,
            title: 'Concatenate files',
            color: const Color(0xFF74F0A2),
          ),
          const SizedBox(height: 10),
          _CompactFilePickerRow(
            label: 'File 1',
            fileName: _concatFirstPath == null
                ? null
                : FileUtils.fileName(_concatFirstPath!),
            buttonText: 'Select',
            color: const Color(0xFF1E8CFF),
            onPressed: _isConcatenating
                ? null
                : () => _pickConcatenationFile(first: true),
          ),
          const SizedBox(height: 8),
          _CompactFilePickerRow(
            label: 'File 2',
            fileName: _concatSecondPath == null
                ? null
                : FileUtils.fileName(_concatSecondPath!),
            buttonText: 'Select',
            color: const Color(0xFF1E8CFF),
            onPressed: _isConcatenating
                ? null
                : () => _pickConcatenationFile(first: false),
          ),
          const Spacer(),
          _ActionButton(
            icon: _isConcatenating ? null : Icons.save_alt_rounded,
            label: _isConcatenating
                ? '${(_concatProgress * 100).round()}%'
                : 'Concatenate & Save WAV',
            color: const Color(0xFF315DAE),
            onPressed: _isConcatenating ? null : _concatenateAndSave,
            busy: _isConcatenating,
          ),
          const SizedBox(height: 7),
          _StatusLine(
              text: _concatMessage ?? 'Select two files, then save result.'),
        ],
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Color color;
  final Color borderColor;
  final Widget child;

  const _GlassPanel(
      {required this.color, required this.borderColor, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor.withOpacity(0.85)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PanelHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _PanelHeader(
      {required this.icon, required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 7),
        Text(
          title,
          style: TextStyle(
              color: color, fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _CompactFilePickerRow extends StatelessWidget {
  final String label;
  final String? fileName;
  final String buttonText;
  final Color color;
  final VoidCallback? onPressed;

  const _CompactFilePickerRow({
    required this.label,
    required this.fileName,
    required this.buttonText,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 47,
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w800)),
        ),
        SizedBox(
          height: 34,
          child: ElevatedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.folder_open_rounded, size: 14),
            label: Text(buttonText),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(76, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              textStyle:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 34,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.18),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Text(
              fileName ?? 'No file',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color color;
  final Future<void> Function()? onPressed;
  final bool busy;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ElevatedButton.icon(
        onPressed: onPressed == null ? null : () => onPressed!(),
        icon: busy
            ? const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Icon(icon, size: 17),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withOpacity(0.45),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final Duration value;
  final String buttonText;
  final Color color;
  final VoidCallback? onPressed;

  const _TimeTile({
    required this.label,
    required this.value,
    required this.buttonText,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(_formatMs(value), style: _monoStyle(11)),
              ],
            ),
          ),
          SizedBox(
            height: 30,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                textStyle:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
              ),
              child: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  final String text;

  const _StatusLine({required this.text});

  @override
  Widget build(BuildContext context) {
    final isError = text.toLowerCase().contains('failed') ||
        text.toLowerCase().contains('required');
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: isError ? Colors.redAccent : Colors.white.withOpacity(0.68),
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

TextStyle _monoStyle(double size) => TextStyle(
      color: Colors.white.withOpacity(0.96),
      fontSize: size,
      fontFamily: 'monospace',
      fontWeight: FontWeight.w800,
    );

String _formatMs(Duration duration) {
  final totalMs = duration.inMilliseconds.clamp(0, 1 << 62);
  final minutes = totalMs ~/ 60000;
  final seconds = (totalMs ~/ 1000) % 60;
  final ms = totalMs % 1000;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}:${ms.toString().padLeft(3, '0')}';
}
