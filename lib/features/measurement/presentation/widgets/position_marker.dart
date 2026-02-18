import 'package:flutter/material.dart';

import 'package:physi_log/shared/extensions/duration_extensions.dart';

class PositionMarker extends StatelessWidget {
  const PositionMarker({
    super.key,
    required this.label,
    this.position,
    required this.onConfirm,
  });

  final String label;
  final Duration? position;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            position?.toTimestamp() ?? '--:--.---',
            style: const TextStyle(
              fontFamily: 'RobotoMono',
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        FilledButton.tonal(
          onPressed: onConfirm,
          child: const Text('確定'),
        ),
      ],
    );
  }
}
