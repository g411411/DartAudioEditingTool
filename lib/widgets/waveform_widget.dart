import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/editor_provider.dart';

class WaveformWidget extends StatefulWidget {
  const WaveformWidget({super.key});

  @override
  State<WaveformWidget> createState() => _WaveformWidgetState();
}

class _WaveformWidgetState extends State<WaveformWidget> {
  static const double _waveformHeight = 160.0;
  String? _dragging; // 'start' | 'end'

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EditorProvider>();
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          height: _waveformHeight,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1B2A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1E3A5F), width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: provider.isLoadingWaveform
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: theme.colorScheme.primary,
                          strokeWidth: 2,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Analyzing audio...',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      return GestureDetector(
                        onHorizontalDragStart: (details) {
                          final startX = provider.startFraction * width;
                          final endX = provider.endFraction * width;
                          // Determine which handle is closest
                          if ((details.localPosition.dx - startX).abs() <
                              (details.localPosition.dx - endX).abs()) {
                            _dragging = 'start';
                          } else {
                            _dragging = 'end';
                          }
                        },
                        onHorizontalDragUpdate: (details) {
                          final fraction =
                              (details.localPosition.dx / width).clamp(0.0, 1.0);
                          if (_dragging == 'start') {
                            provider.setStartFraction(fraction);
                          } else {
                            provider.setEndFraction(fraction);
                          }
                        },
                        onHorizontalDragEnd: (_) {
                          _dragging = null;
                        },
                        child: CustomPaint(
                          size: Size(width, _waveformHeight),
                          painter: _WaveformPainter(
                            samples: provider.waveformData,
                            startFraction: provider.startFraction,
                            endFraction: provider.endFraction,
                            playheadFraction: provider.playheadFraction,
                            accentColor: theme.colorScheme.primary,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> samples;
  final double startFraction;
  final double endFraction;
  final double playheadFraction;
  final Color accentColor;

  const _WaveformPainter({
    required this.samples,
    required this.startFraction,
    required this.endFraction,
    required this.playheadFraction,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;

    final double startX = startFraction * size.width;
    final double endX = endFraction * size.width;
    final double midY = size.height / 2;
    final double barWidth = size.width / samples.length;
    final double maxBarHeight = size.height * 0.45;

    // Unselected bar paint
    final unselectedPaint = Paint()
      ..color = const Color(0xFF2A3A4A)
      ..strokeCap = StrokeCap.round;

    // Selected bar paint
    final selectedPaint = Paint()
      ..color = accentColor
      ..strokeCap = StrokeCap.round;

    // Draw waveform bars
    for (int i = 0; i < samples.length; i++) {
      final x = i * barWidth + barWidth / 2;
      final amplitude = samples[i].clamp(0.01, 1.0);
      final barHeight = amplitude * maxBarHeight;

      final inSelection = x >= startX && x <= endX;
      final paint = inSelection ? selectedPaint : unselectedPaint;

      canvas.drawLine(
        Offset(x, midY - barHeight),
        Offset(x, midY + barHeight),
        paint..strokeWidth = (barWidth * 0.6).clamp(1.0, 3.0),
      );
    }

    // Draw dimming overlay outside selection
    final dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.45);
    // Left dim
    canvas.drawRect(Rect.fromLTWH(0, 0, startX, size.height), dimPaint);
    // Right dim
    canvas.drawRect(
        Rect.fromLTWH(endX, 0, size.width - endX, size.height), dimPaint);

    // Draw selection highlight overlay
    final highlightPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.08);
    canvas.drawRect(
        Rect.fromLTWH(startX, 0, endX - startX, size.height), highlightPaint);

    // Draw start handle
    _drawHandle(canvas, size, startX, isStart: true);

    // Draw end handle
    _drawHandle(canvas, size, endX, isStart: false);

    // Draw playhead
    if (playheadFraction > 0) {
      final px = playheadFraction * size.width;
      final playheadPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(px, 0), Offset(px, size.height), playheadPaint);

      // Playhead dot
      canvas.drawCircle(
        Offset(px, 8),
        5,
        Paint()..color = Colors.white,
      );
    }
  }

  void _drawHandle(Canvas canvas, Size size, double x, {required bool isStart}) {
    // Handle line
    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);

    // Handle grip tab
    const double tabWidth = 14.0;
    const double tabHeight = 28.0;
    final tabX = isStart ? x : x - tabWidth;
    final tabY = size.height / 2 - tabHeight / 2;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(tabX, tabY, tabWidth, tabHeight),
      const Radius.circular(4),
    );

    canvas.drawRRect(rrect, Paint()..color = Colors.white);

    // Grip lines
    final gripPaint = Paint()
      ..color = const Color(0xFF0D1B2A)
      ..strokeWidth = 1.5;
    for (int i = -1; i <= 1; i++) {
      final gx = tabX + tabWidth / 2 + i * 3.5;
      canvas.drawLine(
        Offset(gx, tabY + 6),
        Offset(gx, tabY + tabHeight - 6),
        gripPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.startFraction != startFraction ||
      old.endFraction != endFraction ||
      old.playheadFraction != playheadFraction ||
      old.samples != samples;
}
