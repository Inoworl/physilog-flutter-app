import 'package:flutter/material.dart';

class SeekControls extends StatelessWidget {
  const SeekControls({
    super.key,
    required this.isPlaying,
    required this.fps,
    required this.onSeekBackward100ms,
    required this.onSeekBackward1Frame,
    required this.onTogglePlay,
    required this.onSeekForward1Frame,
    required this.onSeekForward100ms,
  });

  final bool isPlaying;
  final double fps;
  final VoidCallback onSeekBackward100ms;
  final VoidCallback onSeekBackward1Frame;
  final VoidCallback onTogglePlay;
  final VoidCallback onSeekForward1Frame;
  final VoidCallback onSeekForward100ms;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SeekButton(
          icon: Icons.fast_rewind,
          label: '0.1s',
          onPressed: onSeekBackward100ms,
        ),
        _SeekButton(
          icon: Icons.skip_previous,
          label: '1f',
          onPressed: onSeekBackward1Frame,
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: onTogglePlay,
          icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
          iconSize: 32,
        ),
        const SizedBox(width: 8),
        _SeekButton(
          icon: Icons.skip_next,
          label: '1f',
          onPressed: onSeekForward1Frame,
        ),
        _SeekButton(
          icon: Icons.fast_forward,
          label: '0.1s',
          onPressed: onSeekForward100ms,
        ),
      ],
    );
  }
}

class _SeekButton extends StatelessWidget {
  const _SeekButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}
