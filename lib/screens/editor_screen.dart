import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/audio_file_model.dart';
import '../providers/editor_provider.dart';
import '../services/export_service.dart';
import '../utils/duration_formatter.dart';
import '../utils/file_utils.dart';
import '../widgets/waveform_widget.dart';
import '../widgets/time_fields_row.dart';
import '../widgets/playback_controls.dart';
import '../widgets/effects_panel.dart';
import '../widgets/format_selector.dart';
import '../widgets/export_dialog.dart';

class EditorScreen extends StatelessWidget {
  final AudioFileModel audioFile;

  const EditorScreen({super.key, required this.audioFile});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EditorProvider(audioFile),
      child: _EditorView(audioFile: audioFile),
    );
  }
}

class _EditorView extends StatefulWidget {
  final AudioFileModel audioFile;
  const _EditorView({required this.audioFile});

  @override
  State<_EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends State<_EditorView> {
  bool _isExporting = false;
  double _exportProgress = 0;
  final TextEditingController _fileNameCtrl = TextEditingController();

  @override
  void dispose() {
    _fileNameCtrl.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop(EditorProvider provider) async {
    if (!provider.hasUnsavedChanges) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F2236),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Discard changes?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'You have unsaved trim settings. Going back will discard them.',
          style: TextStyle(color: Colors.white.withOpacity(0.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Discard',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _exportAudio(EditorProvider provider) async {
    // M4R duration check
    if (provider.isM4rTooLong) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('M4R ringtones must be 40 seconds or less.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Sync filename from controller
    final fileName = _fileNameCtrl.text.trim();
    if (fileName.isNotEmpty) provider.setOutputFileName(fileName);

    setState(() { _isExporting = true; _exportProgress = 0; });

    try {
      final settings = provider.buildTrimSettings();
      final result = await ExportService.export(
        inputPath: widget.audioFile.path,
        settings: settings,
        onProgress: (p) => setState(() => _exportProgress = p),
      );

      if (!mounted) return;
      setState(() { _isExporting = false; });

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => ExportDialog(
          result: result,
          onTrimAnother: () => Navigator.of(context).pop(),
        ),
      );
    } catch (e) {
      setState(() { _isExporting = false; });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<EditorProvider>(
      builder: (context, provider, _) {
        // Keep filename controller in sync
        if (!_fileNameCtrl.text.contains(provider.outputFileName) ||
            _fileNameCtrl.text.isEmpty) {
          _fileNameCtrl.text = provider.outputFileName;
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final shouldPop = await _onWillPop(provider);
            if (shouldPop && context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: Scaffold(
            backgroundColor: const Color(0xFF070F1A),
            appBar: AppBar(
              backgroundColor: const Color(0xFF0D1B2A),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded,
                    color: Colors.white70),
                onPressed: () async {
                  final shouldPop = await _onWillPop(provider);
                  if (shouldPop && context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.audioFile.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${DurationFormatter.formatShort(widget.audioFile.duration)} · ${widget.audioFile.sizeFormatted}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.4)),
                  ),
                  child: Text(
                    FileUtils.extension(widget.audioFile.path).toUpperCase(),
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            body: _isExporting
                ? _ExportingOverlay(progress: _exportProgress)
                : SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),

                        // Section label
                        _SectionLabel(label: 'WAVEFORM'),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: const WaveformWidget(),
                        ),

                        const SizedBox(height: 16),

                        // Time fields
                        const TimeFieldsRow(),

                        const SizedBox(height: 24),

                        // Playback controls
                        const PlaybackControls(),

                        const SizedBox(height: 28),

                        // Effects
                        _SectionLabel(label: 'EFFECTS'),
                        const SizedBox(height: 8),
                        const EffectsPanel(),

                        const SizedBox(height: 24),

                        // Format selector
                        _SectionLabel(label: 'OUTPUT'),
                        const SizedBox(height: 8),
                        const FormatSelector(),

                        const SizedBox(height: 20),

                        // Filename field
                        _SectionLabel(label: 'FILENAME'),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TextField(
                            controller: _fileNameCtrl,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFF0F2236),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFF1E3A5F)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFF1E3A5F)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: theme.colorScheme.primary,
                                    width: 1.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              prefixIcon: Icon(Icons.drive_file_rename_outline,
                                  color: Colors.white38, size: 18),
                              suffixIcon: IconButton(
                                icon: Icon(Icons.clear,
                                    color: Colors.white38, size: 16),
                                onPressed: () => _fileNameCtrl.clear(),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Export button
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: ElevatedButton(
                              onPressed: provider.isM4rTooLong
                                  ? null
                                  : () => _exportAudio(provider),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    Colors.grey.withOpacity(0.3),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.content_cut_rounded,
                                      size: 20),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Trim & Export',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _ExportingOverlay extends StatelessWidget {
  final double progress;
  const _ExportingOverlay({required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                value: progress > 0 ? progress : null,
                color: theme.colorScheme.primary,
                strokeWidth: 4,
                backgroundColor: const Color(0xFF1E3A5F),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Exporting...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress > 0 ? progress : null,
                backgroundColor: const Color(0xFF1E3A5F),
                valueColor:
                    AlwaysStoppedAnimation(theme.colorScheme.primary),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withOpacity(0.35),
          fontSize: 10,
          letterSpacing: 2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
