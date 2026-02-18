import 'package:flutter/material.dart';

class CompressProgressDialog extends StatelessWidget {
  const CompressProgressDialog({super.key, required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final percent = (progress).clamp(0, 100).toInt();

    return AlertDialog(
      title: const Text('動画を圧縮中'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: progress / 100),
          const SizedBox(height: 16),
          Text('$percent%', style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
