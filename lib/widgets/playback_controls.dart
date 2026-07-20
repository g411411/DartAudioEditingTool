import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/editor_provider.dart';

class PlaybackControls extends StatelessWidget {
  const PlaybackControls({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EditorProvider>();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // ── Main playback row ──────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Stop & Set End button
              _ControlButton(
                icon: Icons.stop_rounded,
                label: 'Set End',
                color: provider.isPlaying
                    ? const Color(0xFF8B0000).withAlpha(180)
                    : const Color(0xFF1A2D42),
                iconColor: provider.isPlaying
                    ? Colors.redAccent
                    : Colors.white54,
                borderColor: provider.isPlaying
                    ? Colors.redAccent.withAlpha(120)
                    : const Color(0xFF1E3A5F),
                tooltip: 'Stop and set end time to current position',
                onTap: () => provider.stopAndSetEnd(),
              ),
              const SizedBox(width: 24),
              // Play / Pause — large accent button
              GestureDetector(
                onTap: () => provider.togglePlayPause(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withAlpha(100),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      provider.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      key: ValueKey(provider.isPlaying),
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              // Reset button
              _ControlButton(
                icon: Icons.replay_rounded,
                label: 'Reset',
                color: const Color(0xFF1A2D42),
                iconColor: Colors.white70,
                borderColor: const Color(0xFF1E3A5F),
                tooltip: 'Reset to beginning',
                onTap: () => provider.stopPlayback(),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Volume control row ─────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Icon(
                  provider.volume == 0
                      ? Icons.volume_off_rounded
                      : provider.volume < 0.5
                          ? Icons.volume_down_rounded
                          : Icons.volume_up_rounded,
                  color: Colors.white54,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7),
                      overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 16),
                    ),
                    child: Slider(
                      value: provider.volume,
                      min: 0.0,
                      max: 1.0,
                      onChanged: (v) => provider.setVolume(v),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 36,
                  child: Text(
                    '${(provider.volume * 100).round()}%',
                    style: TextStyle(
                      color: Colors.white.withAlpha(120),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),

          // ── Stop indicator hint (shown while playing) ───────
          if (provider.isPlaying)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.stop_rounded,
                      color: Colors.redAccent.withAlpha(180), size: 13),
                  const SizedBox(width: 4),
                  Text(
                    'Press Stop to set end time at current position',
                    style: TextStyle(
                      color: Colors.redAccent.withAlpha(180),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color iconColor;
  final Color borderColor;
  final String tooltip;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.iconColor,
    required this.borderColor,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
      ),
    );
  }
}
