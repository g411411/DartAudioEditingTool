import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/trim_settings_model.dart';
import '../providers/editor_provider.dart';

class FormatSelector extends StatelessWidget {
  const FormatSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EditorProvider>();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OUTPUT FORMAT',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F2236),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E3A5F)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<OutputFormat>(
                value: provider.outputFormat,
                isExpanded: true,
                dropdownColor: const Color(0xFF0F2236),
                iconEnabledColor: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                borderRadius: BorderRadius.circular(12),
                items: OutputFormat.values.map((fmt) {
                  return DropdownMenuItem(
                    value: fmt,
                    child: Row(
                      children: [
                        _FormatIcon(format: fmt),
                        const SizedBox(width: 12),
                        Text(
                          fmt.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDescription(fmt),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (fmt) {
                  if (fmt != null) provider.setOutputFormat(fmt);
                },
              ),
            ),
          ),
          // M4R info chip
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: provider.outputFormat == OutputFormat.m4r
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A3A1A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.greenAccent.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.phone_iphone_rounded,
                              color: Colors.greenAccent, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Ideal for iPhone ringtones. Duration limited to 40 seconds.',
                              style: TextStyle(
                                color: Colors.greenAccent.withOpacity(0.9),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          // M4R too-long warning
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: provider.isM4rTooLong
                ? Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3A1A1A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.redAccent.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Colors.redAccent, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Selection is longer than 40 seconds. Please shorten it for M4R.',
                              style: TextStyle(
                                color: Colors.redAccent.withOpacity(0.9),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  String _formatDescription(OutputFormat fmt) {
    switch (fmt) {
      case OutputFormat.wav:
        return '· Lossless';
      case OutputFormat.m4a:
        return '· High quality';
      case OutputFormat.m4r:
        return '· iPhone ringtone';
      case OutputFormat.aac:
        return '· Compact';
    }
  }
}

class _FormatIcon extends StatelessWidget {
  final OutputFormat format;
  const _FormatIcon({required this.format});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (format) {
      case OutputFormat.wav:
        color = const Color(0xFF3D8EF8);
        break;
      case OutputFormat.m4a:
        color = const Color(0xFF00D4FF);
        break;
      case OutputFormat.m4r:
        color = Colors.greenAccent;
        break;
      case OutputFormat.aac:
        color = const Color(0xFFFFB347);
        break;
    }
    return Container(
      width: 28,
      height: 20,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Center(
        child: Text(
          format.label,
          style: TextStyle(
            color: color,
            fontSize: 8,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
