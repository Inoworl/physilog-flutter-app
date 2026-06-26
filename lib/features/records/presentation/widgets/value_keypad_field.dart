import 'package:flutter/material.dart';
import 'package:physi_log/app/theme/app_colors.dart';
import 'package:physi_log/features/measurement/application/min_sec_input.dart';
import 'package:physi_log/models/event.dart';
import 'package:physi_log/shared/widgets/numeric_keypad_grid.dart';

/// 記録値の手入力フィールド（数字パッド）。計測会と同じ操作感を手動記録・
/// 記録編集でも使えるようにする共通ウィジェット。
///
/// - タイム種目は「秒 / 分:秒」トグルを出す（分:秒は右詰めで m:ss）。
/// - 回数種目は小数キーを出さない。
/// - 入力値が変わるたび [onChanged] へ現在値（解釈できなければ null）を返す。
class ValueKeypadField extends StatefulWidget {
  const ValueKeypadField({
    super.key,
    required this.recordType,
    required this.unit,
    required this.onChanged,
    this.initialValue,
  });

  final EventRecordType recordType;
  final String unit;
  final double? initialValue;
  final ValueChanged<double?> onChanged;

  @override
  State<ValueKeypadField> createState() => _ValueKeypadFieldState();
}

class _ValueKeypadFieldState extends State<ValueKeypadField> {
  String _input = '';
  bool _timeMode = false;

  bool get _isInteger => widget.recordType == EventRecordType.count;
  bool get _isTime => widget.recordType == EventRecordType.time;

  @override
  void initState() {
    super.initState();
    _seedFromInitial();
  }

  void _seedFromInitial() {
    final value = widget.initialValue;
    if (value == null || value <= 0) return;
    if (_isTime && value >= 60) {
      // 1分以上のタイムは分:秒モードで mmss を初期表示する。
      _timeMode = true;
      final total = value.round();
      final min = total ~/ 60;
      final sec = total % 60;
      _input = '$min${sec.toString().padLeft(2, '0')}';
    } else {
      _input = _trimNumber(value);
    }
  }

  String _trimNumber(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toString();
  }

  double? _currentValue() {
    if (_isTime && _timeMode) return MinSecInput.toSeconds(_input);
    final cleaned = _input.endsWith('.')
        ? _input.substring(0, _input.length - 1)
        : _input;
    return double.tryParse(cleaned);
  }

  void _onKey(String key) {
    setState(() {
      if (key == '⌫') {
        if (_input.isNotEmpty) {
          _input = _input.substring(0, _input.length - 1);
        }
      } else if (_isTime && _timeMode) {
        if (key == '.') return;
        if (_input.length >= 4) return;
        if (_input.isEmpty && key == '0') return;
        _input = '$_input$key';
      } else if (key == '.') {
        if (_input.contains('.') || _input.isEmpty) return;
        _input = '$_input.';
      } else if (_input == '0') {
        _input = key;
      } else {
        _input = '$_input$key';
      }
    });
    widget.onChanged(_currentValue());
  }

  void _setTimeMode(bool value) {
    setState(() {
      _timeMode = value;
      _input = '';
    });
    widget.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final allowDecimal = !_isInteger && !(_isTime && _timeMode);
    final display = (_isTime && _timeMode)
        ? MinSecInput.format(_input)
        : _input;
    final unitLabel = (_isTime && _timeMode) ? '分:秒' : widget.unit;
    final hasInput = display.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              hasInput ? display : '0',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: hasInput
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Text(unitLabel, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        if (_isTime) ...[
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('秒')),
              ButtonSegment(value: true, label: Text('分:秒')),
            ],
            selected: {_timeMode},
            showSelectedIcon: false,
            onSelectionChanged: (selected) => _setTimeMode(selected.first),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        NumericKeypadGrid(allowDecimal: allowDecimal, onKey: _onKey),
      ],
    );
  }
}
