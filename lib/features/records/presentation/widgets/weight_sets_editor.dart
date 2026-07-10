import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:physi_log/models/record_set.dart';

/// ウェイト種目のセット（重さ×回数）を行で入力するエディタ。
///
/// 「セットを追加」で行を増やし、各行に重さ(kg)と回数を入れる。
/// 入力が変わるたび、有効な行（重さ>0・回数>0）だけを [onChanged] に返す。
class WeightSetsEditor extends StatefulWidget {
  const WeightSetsEditor({super.key, required this.onChanged});

  final ValueChanged<List<RecordSet>> onChanged;

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
    for (final row in _rows) {
      final weight = double.tryParse(row.weight.text.trim());
      final reps = int.tryParse(row.reps.text.trim());
      if (weight != null && weight > 0 && reps != null && reps > 0) {
        sets.add(RecordSet(weight: weight, reps: reps));
      }
    }
    widget.onChanged(sets);
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
