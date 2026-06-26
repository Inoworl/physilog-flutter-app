import 'package:flutter/material.dart';
import 'package:physi_log/app/theme/app_colors.dart';

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
            _KeypadGrid(allowDecimal: allowDecimal, onKey: onKey),
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

class _KeypadGrid extends StatelessWidget {
  const _KeypadGrid({required this.allowDecimal, required this.onKey});

  final bool allowDecimal;
  final ValueChanged<String> onKey;

  @override
  Widget build(BuildContext context) {
    final keys = <String>[
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      allowDecimal ? '.' : '',
      '0',
      '⌫',
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 2.2,
      children: [
        for (final key in keys) _KeypadButton(label: key, onKey: onKey),
      ],
    );
  }
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({required this.label, required this.onKey});

  final String label;
  final ValueChanged<String> onKey;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) {
      return const SizedBox.shrink();
    }
    return OutlinedButton(
      onPressed: () => onKey(label),
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, style: Theme.of(context).textTheme.headlineSmall),
    );
  }
}
