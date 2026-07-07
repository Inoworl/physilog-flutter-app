import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:physi_log/app/theme/app_colors.dart';
import 'package:physi_log/app/theme/app_text_styles.dart';
import 'package:physi_log/features/manage/application/event_list_notifier.dart';
import 'package:physi_log/models/event.dart';
import 'package:physi_log/shared/constants/app_constants.dart';

class EventFormSheet extends ConsumerStatefulWidget {
  const EventFormSheet({super.key, this.event});

  final Event? event;

  static Future<void> show(BuildContext context, {Event? event}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => EventFormSheet(event: event),
    );
  }

  @override
  ConsumerState<EventFormSheet> createState() => _EventFormSheetState();
}

class _EventFormSheetState extends ConsumerState<EventFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _unitController;
  late EventRecordType _recordType;
  late EventMeasurementMethod _measurementMethod;
  late EventScoreDirection _scoreDirection;
  bool _isSubmitting = false;

  bool get _isEditing => widget.event != null;

  static const _unitPresets = ['秒', 'cm', 'm', 'kg', '回', '%', '点', 'レベル'];

  EventScoreDirection _defaultDirectionFor(EventRecordType type) =>
      type.lowerIsBetter
      ? EventScoreDirection.lower
      : EventScoreDirection.higher;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _nameController = TextEditingController(text: event?.name);
    _recordType = event?.recordType ?? EventRecordType.time;
    _measurementMethod =
        event?.measurementMethod ?? _recordType.defaultMeasurementMethod;
    _scoreDirection =
        event?.effectiveScoreDirection ?? _defaultDirectionFor(_recordType);
    _unitController = TextEditingController(
      text: event?.unit ?? _recordType.defaultUnit,
    );
  }

  /// 記録の型を切り替えたとき、計測方法・単位・ベスト方向をその型の既定に
  /// 合わせる（新規作成時のみ）。
  void _onRecordTypeChanged(EventRecordType type) {
    setState(() {
      _recordType = type;
      _measurementMethod = type.defaultMeasurementMethod;
      _scoreDirection = _defaultDirectionFor(type);
      _unitController.text = type.defaultUnit;
    });
  }

  String? get _recordTypeHint => _isEditing ? '作成後は変更できません' : null;

  void _handleRecordTypeChanged(Set<EventRecordType> selection) {
    _onRecordTypeChanged(selection.first);
  }

  void _handleMethodChanged(Set<EventMeasurementMethod> selection) {
    setState(() => _measurementMethod = selection.first);
  }

  Widget _buildRecordTypeSelector() {
    return SegmentedButton<EventRecordType>(
      segments: [
        for (final type in EventRecordType.values)
          ButtonSegment(value: type, label: Text(type.label)),
      ],
      selected: {_recordType},
      showSelectedIcon: false,
      // 編集時は記録の型を固定する（既存記録の単位を壊さないため）。
      onSelectionChanged: _isEditing ? null : _handleRecordTypeChanged,
    );
  }

  Widget _buildMethodSelector() {
    return SegmentedButton<EventMeasurementMethod>(
      segments: [
        for (final method in EventMeasurementMethod.values)
          ButtonSegment(value: method, label: Text(method.label)),
      ],
      selected: {_measurementMethod},
      showSelectedIcon: false,
      onSelectionChanged: _handleMethodChanged,
    );
  }

  Widget _buildUnitField() {
    return TextFormField(
      controller: _unitController,
      readOnly: _isEditing,
      decoration: InputDecoration(
        labelText: '単位',
        hintText: '例: 秒 / cm / kg / 回 / %',
        helperText: _isEditing ? '作成後は変更できません' : null,
      ),
      validator: (value) {
        final trimmed = value?.trim() ?? '';
        if (trimmed.isEmpty) return '単位を入力してください';
        return null;
      },
    );
  }

  Widget _buildUnitPresets() {
    return Wrap(
      spacing: 8,
      children: [
        for (final unit in _unitPresets)
          ActionChip(
            label: Text(unit),
            onPressed: () => setState(() => _unitController.text = unit),
          ),
      ],
    );
  }

  /// ベスト方向（大きい/小さい/順位なし）。記録があっても変更できる。
  Widget _buildDirectionSelector() {
    return Wrap(
      spacing: 8,
      children: [
        for (final direction in EventScoreDirection.values)
          ChoiceChip(
            label: Text(direction.label),
            selected: _scoreDirection == direction,
            onSelected: (_) => setState(() => _scoreDirection = direction),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    final notifier = ref.read(eventListNotifierProvider.notifier);
    try {
      if (_isEditing) {
        await notifier.updateEvent(
          eventId: widget.event!.id,
          name: _nameController.text.trim(),
          measurementMethod: _measurementMethod,
          scoreDirection: _scoreDirection,
        );
      } else {
        await notifier.addEvent(
          _nameController.text.trim(),
          recordType: _recordType,
          measurementMethod: _measurementMethod,
          unit: _unitController.text.trim(),
          scoreDirection: _scoreDirection,
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _delete() async {
    if (widget.event == null || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(eventListNotifierProvider.notifier)
          .deleteEvent(widget.event!.id);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('削除に失敗しました: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 0, 24, bottomInset + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? '種目を編集' : '種目を追加',
              style: AppTextStyles.sectionTitle,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '種目名'),
              textInputAction: TextInputAction.done,
              maxLength: AppConstants.maxEventTypeLength,
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) {
                  return '種目名を入力してください';
                }
                if (trimmed.length > AppConstants.maxEventTypeLength) {
                  return '${AppConstants.maxEventTypeLength}文字以内で入力してください';
                }
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
            _FieldLabel('記録の型', hint: _recordTypeHint),
            const SizedBox(height: 8),
            _buildRecordTypeSelector(),
            const SizedBox(height: 20),
            const _FieldLabel('単位'),
            const SizedBox(height: 8),
            _buildUnitField(),
            if (!_isEditing) ...[
              const SizedBox(height: 8),
              _buildUnitPresets(),
            ],
            const SizedBox(height: 20),
            const _FieldLabel('ベスト方向'),
            const SizedBox(height: 8),
            _buildDirectionSelector(),
            const SizedBox(height: 20),
            const _FieldLabel('計測方法'),
            const SizedBox(height: 8),
            _buildMethodSelector(),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: Text(_isEditing ? '更新する' : '登録する'),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _isSubmitting ? null : _delete,
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('この種目を削除'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 入力欄の上に置く小見出し。右側に補足ヒントを薄字で表示できる。
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {this.hint});

  final String text;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(text, style: theme.textTheme.titleSmall),
        if (hint != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hint!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
