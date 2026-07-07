import 'package:flutter/material.dart';
import 'package:physi_log/app/theme/app_colors.dart';
import 'package:physi_log/shared/widgets/numeric_keypad_grid.dart';

/// 計測会の連続手入力用キーパッド。値の表示・数字パッド・「保存して次へ」を1枚に。
///
/// [allowDecimal] が false（回数など整数の型）のときは小数点キーを出さない。
class SessionKeypad extends StatelessWidget {
  const SessionKeypad({
    super.key,
    required this.input,
    required this.unit,
    required this.allowDecimal,
    required this.onKey,
    required this.onSave,
  });

  final String input;
  final String unit;
  final bool allowDecimal;
  final ValueChanged<String> onKey;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final hasInput = input.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 値の表示
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  hasInput ? input : '0',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: hasInput
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 6),
                Text(unit, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            NumericKeypadGrid(allowDecimal: allowDecimal, onKey: onKey),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: hasInput ? onSave : null,
                icon: const Icon(Icons.check),
                label: const Text('保存して次へ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
