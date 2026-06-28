import 'package:flutter/material.dart';
import 'package:physi_log/app/theme/app_colors.dart';

/// 数字キーパッドのグリッド（1〜9・小数点・0・⌫）。
///
/// 計測会・手入力など複数の入力UIで共通利用する。[allowDecimal] が false の
/// ときは小数点キーを出さない。押されたキー文字（数字 / '.' / '⌫'）を [onKey] へ。
class NumericKeypadGrid extends StatelessWidget {
  const NumericKeypadGrid({
    super.key,
    required this.allowDecimal,
    required this.onKey,
  });

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
