import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/audio_file_model.dart';
import '../utils/file_utils.dart';
import 'editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  AudioFileModel? _selectedFile;
  bool _isLoading = false;
  String? _errorMessage;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      // Request permissions on Android
      if (!kIsWeb && Platform.isAndroid) {
        final status = await Permission.audio.request();
        if (!status.isGranted) {
          final storageStatus = await Permission.storage.request();
          if (!storageStatus.isGranted) {
            setState(() {
              _errorMessage = 'Storage permission is required to pick audio files.';
              _isLoading = false;
            });
            return;
          }
        }
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a'],
        withData: false,
      );

      if (result == null || result.files.isEmpty) {
        setState(() { _isLoading = false; });
        return;
      }

      final file = result.files.first;
      final path = file.path;
      if (path == null) {
        setState(() {
          _errorMessage = kIsWeb
              ? 'Web preview is not fully supported because audio trimming/export uses native FFmpeg. Please run on Android or iOS.'
              : 'Could not access the selected file.';
          _isLoading = false;
        });
        return;
      }

      // Get duration via just_audio
      Duration duration = Duration.zero;
      try {
        final player = AudioPlayer();
        final d = await player.setFilePath(path);
        duration = d ?? Duration.zero;
        await player.dispose();
      } catch (_) {}

      final audioFile = AudioFileModel(
        path: path,
        name: FileUtils.fileName(path),
        duration: duration,
        sizeBytes: FileUtils.getFileSize(path),
      );

      if (!mounted) return;

      setState(() {
        _selectedFile = audioFile;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedFile != null) {
      return EditorScreen(
        audioFile: _selectedFile!,
        onGoHome: () {
          setState(() {
            _selectedFile = null;
          });
        },
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF070F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        elevation: 0,
        leading: const IconButton(
          icon: Icon(Icons.home_rounded, color: Colors.white30),
          onPressed: null,
        ),
        title: const Text('Audio Trimmer'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                const SizedBox(height: 48),
                // App logo / icon
                ScaleTransition(
                  scale: _pulseAnim,
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          const Color(0xFF00D4FF),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.4),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.content_cut_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      const Color(0xFF00D4FF),
                    ],
                  ).createShader(bounds),
                  child: const Text(
                    'Audio Trimmer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Trim, fade, and export your audio files',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 14,
                  ),
                ),
                if (kIsWeb) ...[
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Colors.orangeAccent, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Note: Running in Web Preview. Native features like audio playback and trimming require an Android or iOS emulator/device.',
                              style: TextStyle(
                                color: Colors.orangeAccent.withOpacity(0.9),
                                fontSize: 12.5,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                // Main pick file button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: GestureDetector(
                    onTap: _isLoading ? null : _pickFile,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1B2A),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _isLoading
                              ? theme.colorScheme.primary.withOpacity(0.6)
                              : const Color(0xFF1E3A5F),
                          width: 2,
                        ),
                      ),
                      child: _isLoading
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(
                                    color: theme.colorScheme.primary,
                                    strokeWidth: 3,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Loading audio...',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.folder_open_rounded,
                                  color: theme.colorScheme.primary,
                                  size: 48,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Select Audio File',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'MP3 · WAV · M4A',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.4),
                                    fontSize: 13,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Format badge row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _FormatBadge(label: 'MP3', color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    _FormatBadge(label: 'WAV', color: const Color(0xFF00D4FF)),
                    const SizedBox(width: 10),
                    _FormatBadge(label: 'M4A', color: const Color(0xFFFFB347)),
                  ],
                ),
                const SizedBox(height: 16),
                // Error message
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Feature list
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  child: Column(
                    children: [
                      _FeatureRow(
                          icon: Icons.content_cut_rounded,
                          text: 'Visual waveform trimming with drag handles'),
                      const SizedBox(height: 10),
                      _FeatureRow(
                          icon: Icons.tune_rounded,
                          text: 'Fade in & fade out effects'),
                      const SizedBox(height: 10),
                      _FeatureRow(
                          icon: Icons.save_alt_rounded,
                          text: 'Export to WAV, M4A, M4R, or AAC'),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  'v1.0.0 · Audio Trimmer',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.2),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      );
          },
        ),
      ),
    );
  }
}

class _FormatBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _FormatBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF1A2D42),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF3D8EF8), size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
