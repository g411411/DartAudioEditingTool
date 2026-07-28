import 'dart:io';
import 'dart:math' as math;
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
import '../widgets/time_fields_row.dart';

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
  String? _lastTrimOutputFileName;
  String? _lastSavedFolderName;
  final TextEditingController _outputNameController = TextEditingController();
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
        _message = null;
        _lastTrimOutputFileName = null;
        _lastSavedFolderName = null;
        _outputNameController.clear();
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

    final defaultOutputFileName =
        '${FileUtils.baseName(file.path)}_trimmed.wav';
    final enteredOutputName = _outputNameController.text;
    final outputFileName = _normalizeOutputFileName(
      enteredOutputName.isEmpty ||
              (_isSavedDestinationDisplay(enteredOutputName) &&
                  _lastTrimOutputFileName != null)
          ? _lastTrimOutputFileName ?? defaultOutputFileName
          : enteredOutputName,
      'wav',
    );
    _lastTrimOutputFileName = outputFileName;

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
          outputFileName: outputFileName,
        ),
        onProgress: (progress) {
          if (mounted) setState(() => _exportProgress = progress);
        },
      );

      if (!mounted) return;
      setState(() => _message = 'Choose save location...');
      final savedPath = await ExportService.saveWithUserChoice(result);
      if (!mounted) return;
      final savedFolderName =
          savedPath == null ? null : _savedFolderName(savedPath);
      setState(() {
        _message = savedFolderName ?? 'Save canceled.';
        if (savedFolderName != null) {
          _lastSavedFolderName = savedFolderName;
          _outputNameController.text = _savedDestinationLabel(savedFolderName);
        }
      });
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

  String _savedFolderName(String savedLocation) {
    final normalized = _decodeSavedLocation(savedLocation.trim())
        .split('?')
        .first
        .replaceAll('\\', '/');
    final pathPart =
        normalized.startsWith('content://') && normalized.contains(':')
            ? normalized.substring(normalized.lastIndexOf(':') + 1)
            : normalized;
    final lastSeparator = pathPart.lastIndexOf('/');

    if (lastSeparator <= 0) {
      return FileUtils.fileName(pathPart);
    }

    final parentPath = pathPart.substring(0, lastSeparator);
    final folderName = parentPath.substring(parentPath.lastIndexOf('/') + 1);
    return folderName.isEmpty ? parentPath : folderName;
  }

  String _decodeSavedLocation(String savedLocation) {
    try {
      return Uri.decodeComponent(savedLocation);
    } catch (_) {
      return savedLocation;
    }
  }

  bool _isSavedDestinationDisplay(String value) {
    final savedFolderName = _lastSavedFolderName;
    return savedFolderName != null &&
        value == _savedDestinationLabel(savedFolderName);
  }

  String _savedDestinationLabel(String folderName) => 'Saved in $folderName';

  String _normalizeOutputFileName(String name, String extension) {
    final safeName = name
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ');
    final cleanExtension = extension.replaceFirst('.', '');

    if (safeName.toLowerCase().endsWith('.$cleanExtension')) {
      return safeName;
    }
    return '$safeName.$cleanExtension';
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
      setState(() => _concatMessage = savedPath == null
          ? 'Save canceled.'
          : _savedDestinationLabel(_savedFolderName(savedPath)));
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

  void _showHelpWalkthrough() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _HelpWalkthroughSheet(),
    );
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
      backgroundColor: const Color(0xFF081321),
      appBar: AppBar(
        backgroundColor: const Color(0xFF081321),
        elevation: 0,
        toolbarHeight: 46,
        titleSpacing: 14,
        title: const Text(
          'Audio Trimmer',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: TextButton.icon(
              onPressed: _showHelpWalkthrough,
              icon: const Icon(Icons.help_outline_rounded, size: 18),
              label: const Text('Help'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF8AB9FF),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
          child: content,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _outputNameController.dispose();
    super.dispose();
  }

  Widget _buildBody(EditorProvider? provider) {
    final hasFile = provider != null && _audioFile != null;
    final start = hasFile ? provider.startDuration : Duration.zero;
    final end = hasFile ? provider.endDuration : Duration.zero;
    final total = _audioFile?.duration ?? Duration.zero;
    final displayEnd = hasFile ? end : total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChooseSourceButton(
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _selectTrimFile,
        ),
        if (_audioFile != null) ...[
          const SizedBox(height: 8),
          _SelectedFileName(fileName: _audioFile!.name),
        ],
        if (_message != null) ...[
          const SizedBox(height: 6),
          _StatusText(text: _message!, color: Colors.white),
        ],
        const SizedBox(height: 10),
        _WaveformSelector(
          enabled: hasFile,
          waveformData: hasFile ? provider.waveformData : const [],
          startFraction: hasFile ? provider.startFraction : 0,
          endFraction: hasFile ? provider.endFraction : 1,
          playheadFraction: hasFile ? provider.playheadFraction : 0,
          onChanged: hasFile
              ? (values) {
                  provider.setStartFraction(values.start);
                  provider.setEndFraction(values.end);
                }
              : null,
        ),
        const SizedBox(height: 8),
        if (hasFile)
          TimeFieldsRow()
        else
          Row(
            children: [
              Text(_formatMs(start), style: _timeStyle),
              const Spacer(),
              Text(_formatMs(displayEnd), style: _timeStyle),
            ],
          ),
        const SizedBox(height: 8),
        _PlaybackRow(
          hasFile: hasFile,
          isPlaying: provider?.isPlaying == true,
          onPlay: hasFile ? provider.togglePlayPause : null,
          onStop: hasFile ? provider.stopPlayback : null,
          onPreview: hasFile ? provider.togglePlayPause : null,
          onRestart: hasFile ? provider.stopPlayback : null,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _FilledButton(
                icon: Icons.vertical_align_top_rounded,
                label: 'Set Start Time',
                color: const Color(0xFF7C4DFF),
                onPressed: hasFile
                    ? () async =>
                        provider.setStartFraction(provider.playheadFraction)
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _FilledButton(
                icon: Icons.vertical_align_bottom_rounded,
                label: 'Set End Time',
                color: const Color(0xFF7C4DFF),
                onPressed: hasFile
                    ? () async =>
                        provider.setEndFraction(provider.playheadFraction)
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _OutputNameField(
          controller: _outputNameController,
          enabled: hasFile && !_isExporting,
          prompt: hasFile ? null : 'Choose a file to trim.',
        ),
        const SizedBox(height: 8),
        _FilledButton(
          icon: _isExporting ? null : Icons.save_alt_rounded,
          label: _isExporting
              ? '${(_exportProgress * 100).round()}%'
              : 'Save Trimmed WAV',
          color: const Color(0xFF1E7BFF),
          onPressed:
              hasFile && !_isExporting ? () => _saveTrimmedWav(provider) : null,
          busy: _isExporting,
          height: 44,
        ),
        const SizedBox(height: 12),
        _buildConcatCard(),
      ],
    );
  }

  Widget _buildConcatCard() {
    final canConcat = _concatFirstPath != null && _concatSecondPath != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFDDF8E8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF9ADBB5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Concatenate Files',
            style: TextStyle(
              color: Color(0xFF10251A),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          _ConcatFileRow(
            fileName: _concatFirstPath == null
                ? 'First audio file'
                : FileUtils.fileName(_concatFirstPath!),
            onPressed: _isConcatenating
                ? null
                : () => _pickConcatenationFile(first: true),
          ),
          const SizedBox(height: 8),
          _ConcatFileRow(
            fileName: _concatSecondPath == null
                ? 'Second audio file'
                : FileUtils.fileName(_concatSecondPath!),
            onPressed: _isConcatenating
                ? null
                : () => _pickConcatenationFile(first: false),
          ),
          const SizedBox(height: 10),
          _FilledButton(
            icon: _isConcatenating ? null : Icons.merge_type_rounded,
            label: _isConcatenating
                ? '${(_concatProgress * 100).round()}%'
                : 'Concatenate & Save WAV',
            color: const Color(0xFF1E7BFF),
            disabledColor: const Color(0xFF9AA1A8),
            onPressed:
                canConcat && !_isConcatenating ? _concatenateAndSave : null,
            busy: _isConcatenating,
            height: 44,
          ),
          const SizedBox(height: 8),
          _StatusText(
            text: _concatMessage ?? 'Choose two files to concatenate.',
            color: Colors.white,
            darkBackground: true,
          ),
        ],
      ),
    );
  }
}

class _HelpWalkthroughSheet extends StatelessWidget {
  const _HelpWalkthroughSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.88,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF101E31),
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
                child: Row(
                  children: [
                    const Icon(
                      Icons.help_outline_rounded,
                      color: Color(0xFF8AB9FF),
                      size: 21,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Help Walkthrough',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: Colors.white70,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Follow these steps to trim a WAV or combine two audio files.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 12,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const _GuideContent(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideContent extends StatelessWidget {
  const _GuideContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GuideSection(
          title: 'Trim Audio',
          accentColor: Color(0xFF1E7BFF),
          backgroundColor: Color(0xFFF4F7FB),
          borderColor: Color(0xFFD9E3EF),
          titleColor: Color(0xFF102033),
          textColor: Color(0xFF26364A),
          steps: [
            _GuideStep(
              icon: Icons.audio_file_rounded,
              color: Color(0xFF1E7BFF),
              text: 'Choose an audio file.',
            ),
            _GuideStep(
              icon: Icons.play_arrow_rounded,
              color: Color(0xFF1E7BFF),
              text: 'Use Play, Stop, and Restart to review the audio.',
            ),
            _GuideStep(
              icon: Icons.tune_rounded,
              color: Color(0xFF7C4DFF),
              text:
                  'Drag the two purple handles on the waveform to select the start and end of the audio.',
            ),
            _GuideStep(
              icon: Icons.text_fields_rounded,
              color: Color(0xFF1E7BFF),
              text: 'Enter the WAV filename, then tap Save Trimmed WAV.',
            ),
          ],
        ),
        _GuideDivider(),
        _GuideSection(
          title: 'Concatenate Audio',
          accentColor: Color(0xFF18A957),
          backgroundColor: Color(0xFFDDF8E8),
          borderColor: Color(0xFF9ADBB5),
          titleColor: Color(0xFF10251A),
          textColor: Color(0xFF10251A),
          steps: [
            _GuideStep(
              icon: Icons.looks_one_rounded,
              color: Color(0xFF138947),
              text: 'Choose file one.',
            ),
            _GuideStep(
              icon: Icons.looks_two_rounded,
              color: Color(0xFF138947),
              text: 'Choose file two.',
            ),
            _GuideStep(
              icon: Icons.merge_type_rounded,
              color: Color(0xFF138947),
              text: 'Tap Concatenate & Save WAV, then choose a save location.',
            ),
          ],
        ),
      ],
    );
  }
}

class _GuideSection extends StatelessWidget {
  final String title;
  final Color accentColor;
  final Color backgroundColor;
  final Color borderColor;
  final Color titleColor;
  final Color textColor;
  final List<_GuideStep> steps;

  const _GuideSection({
    required this.title,
    required this.accentColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.titleColor,
    required this.textColor,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                title,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          ...steps.map((step) => step.withTextColor(textColor)),
        ],
      ),
    );
  }
}

class _GuideDivider extends StatelessWidget {
  const _GuideDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        height: 1,
        color: const Color(0xFF4A5D73),
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final Color? textColor;

  const _GuideStep({
    required this.icon,
    required this.color,
    required this.text,
    this.textColor,
  });

  _GuideStep withTextColor(Color color) {
    return _GuideStep(
      icon: icon,
      color: this.color,
      text: text,
      textColor: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: textColor ?? Colors.white.withValues(alpha: 0.82),
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChooseSourceButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const _ChooseSourceButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E7BFF),
          disabledBackgroundColor: const Color(0xFF52667C),
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.audio_file_rounded, size: 22),
            const SizedBox(width: 10),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLoading ? 'Loading...' : 'Choose Audio File',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'MP3 · WAV · M4A · AAC',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedFileName extends StatelessWidget {
  final String fileName;

  const _SelectedFileName({required this.fileName});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF101E31),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF263C58)),
      ),
      child: Text(
        fileName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _WaveformSelector extends StatelessWidget {
  final bool enabled;
  final List<double> waveformData;
  final double startFraction;
  final double endFraction;
  final double playheadFraction;
  final ValueChanged<RangeValues>? onChanged;

  const _WaveformSelector({
    required this.enabled,
    required this.waveformData,
    required this.startFraction,
    required this.endFraction,
    required this.playheadFraction,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final values = RangeValues(
      startFraction.clamp(0.0, 1.0),
      endFraction.clamp(0.0, 1.0),
    );

    return SizedBox(
      height: 126,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _SelectionWaveformPainter(
                waveformData: waveformData,
                startFraction: values.start,
                endFraction: values.end,
                playheadFraction: playheadFraction,
                enabled: enabled,
              ),
            ),
          ),
          Positioned.fill(
            child: SliderTheme(
              data: const SliderThemeData(
                trackHeight: 0,
                activeTrackColor: Colors.transparent,
                inactiveTrackColor: Colors.transparent,
                thumbColor: Color(0xFFB883FF),
                disabledThumbColor: Color(0xFF586171),
                overlayColor: Color(0x33B883FF),
                rangeThumbShape:
                    RoundRangeSliderThumbShape(enabledThumbRadius: 13),
              ),
              child: RangeSlider(
                values: values,
                min: 0,
                max: 1,
                onChanged: enabled ? onChanged : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionWaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final double startFraction;
  final double endFraction;
  final double playheadFraction;
  final bool enabled;

  const _SelectionWaveformPainter({
    required this.waveformData,
    required this.startFraction,
    required this.endFraction,
    required this.playheadFraction,
    required this.enabled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final background = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(14),
    );
    canvas.drawRRect(background, Paint()..color = const Color(0xFF101E31));

    final startX = size.width * startFraction;
    final endX = size.width * endFraction;
    canvas.drawRect(
      Rect.fromLTRB(startX, 0, endX, size.height),
      Paint()
        ..color = enabled ? const Color(0x332FB7FF) : const Color(0x22586171),
    );

    final barCount = math.max(44, (size.width / 6).floor());
    final gap = size.width / barCount;
    final centerY = size.height / 2;
    final selectedPaint = Paint()
      ..color = enabled ? const Color(0xFF64D7FF) : const Color(0xFF697485)
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round;
    final idlePaint = Paint()
      ..color = const Color(0xFF3A4B63)
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round;

    final maxAmp = waveformData.isEmpty
        ? 1.0
        : waveformData.fold<double>(
            0.08, (max, value) => math.max(max, value.abs()));

    for (var i = 0; i < barCount; i++) {
      final x = (i + 0.5) * gap;
      final amplitude = waveformData.isEmpty
          ? _syntheticAmplitude(i)
          : _waveAmplitude(i, barCount, maxAmp);
      final height = (size.height * 0.18) + (size.height * 0.68 * amplitude);
      final paint = x >= startX && x <= endX ? selectedPaint : idlePaint;
      canvas.drawLine(
        Offset(x, centerY - height / 2),
        Offset(x, centerY + height / 2),
        paint,
      );
    }

    if (enabled) {
      final playheadX = size.width * playheadFraction.clamp(0.0, 1.0);
      canvas.drawLine(
        Offset(playheadX, 8),
        Offset(playheadX, size.height - 8),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  double _waveAmplitude(int index, int count, double maxAmp) {
    final sourceIndex =
        ((index / (count - 1)) * (waveformData.length - 1)).round();
    return math
        .sqrt((waveformData[sourceIndex].abs() / maxAmp).clamp(0.0, 1.0));
  }

  double _syntheticAmplitude(int index) {
    return 0.25 + ((math.sin(index * 0.72) + 1) * 0.5 * 0.75);
  }

  @override
  bool shouldRepaint(covariant _SelectionWaveformPainter oldDelegate) {
    return oldDelegate.waveformData != waveformData ||
        oldDelegate.startFraction != startFraction ||
        oldDelegate.endFraction != endFraction ||
        oldDelegate.playheadFraction != playheadFraction ||
        oldDelegate.enabled != enabled;
  }
}

class _PlaybackRow extends StatelessWidget {
  final bool hasFile;
  final bool isPlaying;
  final Future<void> Function()? onPlay;
  final Future<void> Function()? onStop;
  final Future<void> Function()? onPreview;
  final Future<void> Function()? onRestart;

  const _PlaybackRow({
    required this.hasFile,
    required this.isPlaying,
    required this.onPlay,
    required this.onStop,
    required this.onPreview,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _FilledButton(
            icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            label: 'Play',
            color: const Color(0xFF18A957),
            onPressed: hasFile ? onPlay : null,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _FilledButton(
            icon: Icons.stop_rounded,
            label: 'Stop',
            color: const Color(0xFFE52A2A),
            onPressed: hasFile ? onStop : null,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _FilledButton(
            icon: Icons.volume_up_rounded,
            label: 'Preview',
            color: const Color(0xFF1E7BFF),
            onPressed: hasFile ? onPreview : null,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _FilledButton(
            icon: Icons.restart_alt_rounded,
            label: 'Restart',
            color: const Color(0xFF1E7BFF),
            onPressed: hasFile ? onRestart : null,
          ),
        ),
      ],
    );
  }
}

class _FilledButton extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color color;
  final Color? disabledColor;
  final Future<void> Function()? onPressed;
  final bool busy;
  final double height;

  const _FilledButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    this.disabledColor,
    this.busy = false,
    this.height = 40,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ElevatedButton.icon(
        onPressed: onPressed == null ? null : () => onPressed!(),
        icon: busy
            ? const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Icon(icon, size: 16),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor:
              disabledColor ?? color.withValues(alpha: 0.42),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white70,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle:
              const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _OutputNameField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final String? prompt;

  const _OutputNameField({
    required this.controller,
    required this.enabled,
    this.prompt,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: TextField(
        controller: controller,
        enabled: enabled,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFF101E31),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          hintText: prompt,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF263C58)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF263C58)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(color: Color(0xFF8AB9FF)),
          ),
        ),
      ),
    );
  }
}

class _ConcatFileRow extends StatelessWidget {
  final String fileName;
  final Future<void> Function()? onPressed;

  const _ConcatFileRow({required this.fileName, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 38,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: const Color(0xFFB8E5CA)),
            ),
            child: Text(
              fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF10251A),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 38,
          child: ElevatedButton.icon(
            onPressed: onPressed == null ? null : () => onPressed!(),
            icon: const Icon(Icons.folder_open_rounded, size: 15),
            label: const Text('Choose File'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E7BFF),
              disabledBackgroundColor: const Color(0xFF9AA1A8),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              textStyle:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusText extends StatelessWidget {
  final String text;
  final Color color;
  final bool darkBackground;

  const _StatusText({
    required this.text,
    required this.color,
    this.darkBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final isError = text.toLowerCase().contains('failed') ||
        text.toLowerCase().contains('required');
    return Container(
      alignment: Alignment.centerLeft,
      padding: darkBackground
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
          : EdgeInsets.zero,
      decoration: darkBackground
          ? BoxDecoration(
              color: const Color(0xFF10251A),
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isError ? Colors.redAccent : color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

const TextStyle _timeStyle = TextStyle(
  color: Colors.white,
  fontSize: 12,
  fontFamily: 'monospace',
  fontWeight: FontWeight.w900,
);

String _formatMs(Duration duration) {
  final totalMs = duration.inMilliseconds.clamp(0, 1 << 62);
  final minutes = totalMs ~/ 60000;
  final seconds = (totalMs ~/ 1000) % 60;
  final ms = totalMs % 1000;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}:${ms.toString().padLeft(3, '0')}';
}
