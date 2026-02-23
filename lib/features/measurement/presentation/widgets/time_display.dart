import 'package:flutter/material.dart';

import 'package:physi_log/app/theme/app_colors.dart';
import 'package:physi_log/app/theme/app_text_styles.dart';
import 'package:physi_log/shared/extensions/duration_extensions.dart';

class TimeDisplay extends StatelessWidget {
  const TimeDisplay({
    super.key,
    this.startPosition,
    this.endPosition,
    this.calculatedTime,
    required this.fps,
    required this.onConfirmStart,
    required this.onConfirmEnd,
  });

  final Duration? startPosition;
  final Duration? endPosition;
  final Duration? calculatedTime;
  final double fps;
  final VoidCallback onConfirmStart;
  final VoidCallback onConfirmEnd;

  @override
  Widget build(BuildContext context) {
    final accuracy = fps > 0 ? 1000 / fps : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.timerBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // 開始位置
          _PositionRow(
            label: '開始',
            position: startPosition,
            onConfirm: onConfirmStart,
          ),
          const SizedBox(height: 8),
          // 終了位置
          _PositionRow(
            label: '終了',
            position: endPosition,
            onConfirm: onConfirmEnd,
          ),
          const SizedBox(height: 16),
          // 算出タイム - ネオングリーン大数字
          Text(
            calculatedTime != null
                ? '${(calculatedTime!.inMilliseconds / 1000).toStringAsFixed(2)}秒'
                : '--.--秒',
            style: AppTextStyles.timeDisplay.copyWith(
              color: AppColors.timerText,
            ),
          ),
          const SizedBox(height: 4),
          // 精度情報
          Text(
            '精度: ±${accuracy.toStringAsFixed(1)}ms (${fps.toInt()}fps)',
            style: AppTextStyles.accuracy.copyWith(
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

class _PositionRow extends StatelessWidget {
  const _PositionRow({
    required this.label,
    this.position,
    required this.onConfirm,
  });

  final String label;
  final Duration? position;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: AppTextStyles.timeDisplaySmall.copyWith(
              color: Colors.white70,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            position?.toTimestamp() ?? '--:--.---',
            style: AppTextStyles.timeDisplaySmall.copyWith(
              color: Colors.white,
            ),
          ),
        ),
        FilledButton.tonal(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white12,
            foregroundColor: Colors.white,
          ),
          onPressed: onConfirm,
          child: const Text('確定'),
        ),
      ],
    );
  }
}
