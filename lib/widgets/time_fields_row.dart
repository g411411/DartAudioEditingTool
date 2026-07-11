import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/editor_provider.dart';
import '../utils/duration_formatter.dart';

class TimeFieldsRow extends StatefulWidget {
  const TimeFieldsRow({super.key});

  @override
  State<TimeFieldsRow> createState() => _TimeFieldsRowState();
}

class _TimeFieldsRowState extends State<TimeFieldsRow> {
  late TextEditingController _startCtrl;
  late TextEditingController _endCtrl;
  bool _startFocused = false;
  bool _endFocused = false;

  @override
  void initState() {
    super.initState();
    _startCtrl = TextEditingController();
    _endCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  void _onStartSubmit(EditorProvider provider, String value) {
    final d = DurationFormatter.tryParse(value);
    if (d != null) provider.setStartDuration(d);
  }

  void _onEndSubmit(EditorProvider provider, String value) {
    final d = DurationFormatter.tryParse(value);
    if (d != null) provider.setEndDuration(d);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EditorProvider>();
    final startStr = DurationFormatter.format(provider.startDuration);
    final endStr = DurationFormatter.format(provider.endDuration);
    final durationStr = DurationFormatter.format(provider.selectionDuration);

    // Sync controllers when not focused
    if (!_startFocused) _startCtrl.text = startStr;
    if (!_endFocused) _endCtrl.text = endStr;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _TimeField(
              label: 'Start',
              controller: _startCtrl,
              onFocusChange: (v) => setState(() => _startFocused = v),
              onSubmit: (v) => _onStartSubmit(provider, v),
            ),
          ),
          const SizedBox(width: 8),
          _DurationDisplay(duration: durationStr),
          const SizedBox(width: 8),
          Expanded(
            child: _TimeField(
              label: 'End',
              controller: _endCtrl,
              onFocusChange: (v) => setState(() => _endFocused = v),
              onSubmit: (v) => _onEndSubmit(provider, v),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<bool> onFocusChange;
  final ValueChanged<String> onSubmit;

  const _TimeField({
    required this.label,
    required this.controller,
    required this.onFocusChange,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 10,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Focus(
          onFocusChange: onFocusChange,
          child: TextField(
            controller: controller,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              filled: true,
              fillColor: const Color(0xFF1A2D42),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF1E3A5F)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF1E3A5F)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary, width: 1.5),
              ),
              hintText: '00:00.00',
              hintStyle:
                  TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
            ),
            onSubmitted: onSubmit,
            textInputAction: TextInputAction.done,
            keyboardType: TextInputType.text,
          ),
        ),
      ],
    );
  }
}

class _DurationDisplay extends StatelessWidget {
  final String duration;
  const _DurationDisplay({required this.duration});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'DURATION',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 10,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1B2A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF1E3A5F)),
          ),
          child: Text(
            duration,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 14,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
