import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/editor_provider.dart';

class EffectsPanel extends StatelessWidget {
  const EffectsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EditorProvider>();
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F2236),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E3A5F), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(
              'EFFECTS',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 10,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // Fade In
          _FadeToggle(
            label: 'Fade In',
            icon: Icons.trending_up_rounded,
            value: provider.fadeIn,
            sliderValue: provider.fadeInDuration,
            onToggle: provider.setFadeIn,
            onSliderChange: provider.setFadeInDuration,
            accentColor: theme.colorScheme.primary,
          ),
          Divider(color: const Color(0xFF1E3A5F), height: 1),
          // Fade Out
          _FadeToggle(
            label: 'Fade Out',
            icon: Icons.trending_down_rounded,
            value: provider.fadeOut,
            sliderValue: provider.fadeOutDuration,
            onToggle: provider.setFadeOut,
            onSliderChange: provider.setFadeOutDuration,
            accentColor: const Color(0xFF00D4FF),
          ),
        ],
      ),
    );
  }
}

class _FadeToggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final double sliderValue;
  final ValueChanged<bool> onToggle;
  final ValueChanged<double> onSliderChange;
  final Color accentColor;

  const _FadeToggle({
    required this.label,
    required this.icon,
    required this.value,
    required this.sliderValue,
    required this.onToggle,
    required this.onSliderChange,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 16),
            Icon(icon, color: value ? accentColor : Colors.white38, size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: value ? Colors.white : Colors.white60,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            Switch(
              value: value,
              onChanged: onToggle,
              activeThumbColor: accentColor,
              activeTrackColor: accentColor.withValues(alpha: 0.3),
              inactiveThumbColor: Colors.white38,
              inactiveTrackColor: const Color(0xFF1E3A5F),
            ),
            const SizedBox(width: 8),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: value
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      Text(
                        '0.1s',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 11,
                        ),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: accentColor,
                            inactiveTrackColor: const Color(0xFF1E3A5F),
                            thumbColor: accentColor,
                            overlayColor: accentColor.withOpacity(0.15),
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 7,
                            ),
                          ),
                          child: Slider(
                            value: sliderValue,
                            min: 0.1,
                            max: 5.0,
                            divisions: 49,
                            onChanged: onSliderChange,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 36,
                        child: Text(
                          '${sliderValue.toStringAsFixed(1)}s',
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
