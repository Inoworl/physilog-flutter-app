import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:physi_log/models/record_set.dart';

/// ウェイト種目のセット（重さ×回数）を行で入力するエディタ。
///
/// 「セットを追加」で行を増やし、各行に重さ(kg)と回数を入れる。
/// 入力が変わるたび、有効な行（重さ>0・回数>0）だけを [onChanged] に返す。
/// 入力があるのに不正な行（片方だけ入力・0以下 等）がある場合は
/// [onValidityChanged] に true を通知する。呼び出し側はこれを見て、
/// 不完全な行を silently に無視したまま保存しないようブロックすること。
class WeightSetsEditor extends StatefulWidget {
  const WeightSetsEditor({
    super.key,
    required this.onChanged,
    this.onValidityChanged,
  });

  final ValueChanged<List<RecordSet>> onChanged;

  /// 入力はあるが不正な行が存在するかどうかの通知（true＝存在する）。
  final ValueChanged<bool>? onValidityChanged;

  @override
  State<WeightSetsEditor> createState() => _WeightSetsEditorState();
}

class _SetRow {
  _SetRow() : weight = TextEditingController(), reps = TextEditingController();

  final TextEditingController weight;
  final TextEditingController reps;

  void dispose() {
    weight.dispose();
    reps.dispose();
  }
}

class _WeightSetsEditorState extends State<WeightSetsEditor> {
  final List<_SetRow> _rows = [_SetRow()];

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _emit() {
    final sets = <RecordSet>[];
    var hasInvalidRow = false;
    for (final row in _rows) {
      final weightText = row.weight.text.trim();
      final repsText = row.reps.text.trim();
      final weight = double.tryParse(weightText);
      final reps = int.tryParse(repsText);
      final isValid = weight != null && weight > 0 && reps != null && reps > 0;
      if (isValid) {
        sets.add(RecordSet(weight: weight, reps: reps));
      } else if (weightText.isNotEmpty || repsText.isNotEmpty) {
        // 片方だけ入力・0以下・不正な数値など、入力はあるが有効なセットに
        // ならない行。silentlyに捨てず、呼び出し側へ不正行の存在を伝える。
        hasInvalidRow = true;
      }
    }
    widget.onChanged(sets);
    widget.onValidityChanged?.call(hasInvalidRow);
  }

  void _addRow() {
    setState(() => _rows.add(_SetRow()));
    _emit();
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) return;
    setState(() => _rows.removeAt(index).dispose());
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _rows.length; i++) ...[
          Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '${i + 1}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _rows[i].weight,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: '重さ',
                    suffixText: 'kg',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => _emit(),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('×'),
              ),
              Expanded(
                child: TextField(
                  controller: _rows[i].reps,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: '回数',
                    suffixText: '回',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => _emit(),
                ),
              ),
              IconButton(
                tooltip: 'この行を削除',
                onPressed: _rows.length <= 1 ? null : () => _removeRow(i),
                icon: const Icon(Icons.remove_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addRow,
            icon: const Icon(Icons.add),
            label: const Text('セットを追加'),
          ),
        ),
      ],
    );
  }
}
