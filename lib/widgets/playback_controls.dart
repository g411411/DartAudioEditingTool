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
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Stop button
          _ControlButton(
            icon: Icons.stop_rounded,
            label: 'Stop',
            color: const Color(0xFF1A2D42),
            iconColor: Colors.white70,
            onTap: () => provider.stopPlayback(),
          ),
          const SizedBox(width: 24),
          // Play/Pause button — larger, accent colored
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
                    color: theme.colorScheme.primary.withOpacity(0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  provider.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  key: ValueKey(provider.isPlaying),
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          // Placeholder for balance (or could be a seek button)
          _ControlButton(
            icon: Icons.replay_rounded,
            label: 'Reset',
            color: const Color(0xFF1A2D42),
            iconColor: Colors.white70,
            onTap: () {
              provider.stopPlayback();
            },
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
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: const Color(0xFF1E3A5F), width: 1),
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
    );
  }
}
