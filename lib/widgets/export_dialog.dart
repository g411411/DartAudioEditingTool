import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/export_service.dart';
import '../utils/duration_formatter.dart';
import '../utils/file_utils.dart';

class ExportDialog extends StatefulWidget {
  final ExportResult result;
  final VoidCallback onTrimAnother;

  const ExportDialog({
    super.key,
    required this.result,
    required this.onTrimAnother,
  });

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  bool _saving = false;
  String? _saveMessage;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    await Share.shareXFiles(
      [XFile(widget.result.outputPath)],
      subject: widget.result.outputFileName,
    );
  }

  Future<void> _saveToDownloads() async {
    setState(() { _saving = true; _saveMessage = null; });
    try {
      final path = await ExportService.saveToDownloads(widget.result);
      setState(() {
        _saving = false;
        _saveMessage = 'Saved to: ${FileUtils.fileName(path)}';
      });
    } catch (e) {
      setState(() {
        _saving = false;
        _saveMessage = 'Save failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            color: const Color(0xFF0F2236),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF1E3A5F), width: 1),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withOpacity(0.15),
                blurRadius: 40,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary.withOpacity(0.2),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1A4A2A),
                        border: Border.all(
                            color: Colors.greenAccent.withOpacity(0.5),
                            width: 2),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.greenAccent,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Export Complete!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              // File info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _InfoRow(
                      icon: Icons.audio_file_rounded,
                      label: 'File',
                      value: widget.result.outputFileName,
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.timer_outlined,
                      label: 'Duration',
                      value: DurationFormatter.format(widget.result.outputDuration),
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.data_usage_rounded,
                      label: 'Size',
                      value: FileUtils.formatFileSize(widget.result.outputSizeBytes),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (_saveMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.greenAccent.withOpacity(0.3)),
                    ),
                    child: Text(
                      _saveMessage!,
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              // Action buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _DialogButton(
                        icon: Icons.share_rounded,
                        label: 'Share',
                        color: theme.colorScheme.primary,
                        onTap: _share,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _saving
                          ? Container(
                              height: 52,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A2D42),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            )
                          : _DialogButton(
                              icon: Icons.download_rounded,
                              label: 'Save',
                              color: const Color(0xFF1A2D42),
                              borderColor: const Color(0xFF1E3A5F),
                              onTap: _saveToDownloads,
                            ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onTrimAnother();
                  },
                  style: TextButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    'Trim Another File',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 14,
                    ),
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 16),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color? borderColor;
  final VoidCallback onTap;

  const _DialogButton({
    required this.icon,
    required this.label,
    required this.color,
    this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 52,
          decoration: boxDecoration(borderColor),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration boxDecoration(Color? border) => BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: border != null ? Border.all(color: border) : null,
      );
}
