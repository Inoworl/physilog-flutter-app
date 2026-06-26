import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:physi_log/features/manage/application/event_list_notifier.dart';
import 'package:physi_log/features/records/application/record_list_notifier.dart';
import 'package:physi_log/features/records/presentation/widgets/value_keypad_field.dart';
import 'package:physi_log/models/event.dart';
import 'package:physi_log/providers/app_providers.dart';
import 'package:physi_log/models/measurement_record.dart';
import 'package:physi_log/shared/constants/app_constants.dart';
import 'package:physi_log/shared/widgets/error_state.dart';
import 'package:physi_log/shared/widgets/loading_state.dart';

final _recordForEditProvider =
    FutureProvider.family<MeasurementRecord?, String>((ref, id) async {
      final userId = ref.watch(currentUserIdProvider);
      if (userId == null) return null;
      final repository = ref.watch(recordRepositoryProvider);
      return repository.getRecord(userId: userId, id: id);
    });

class RecordEditScreen extends ConsumerStatefulWidget {
  const RecordEditScreen({super.key, required this.recordId});

  final String recordId;

  @override
  ConsumerState<RecordEditScreen> createState() => _RecordEditScreenState();
}

class _RecordEditScreenState extends ConsumerState<RecordEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _athleteNameController;
  late TextEditingController _memoController;
  String? _selectedEventType;
  double? _recordValue;
  late DateTime _measuredDate;
  bool _initialized = false;
  bool _isSaving = false;

  @override
  void dispose() {
    if (_initialized) {
      _athleteNameController.dispose();
      _memoController.dispose();
    }
    super.dispose();
  }

  void _initControllers(MeasurementRecord record) {
    if (!_initialized) {
      _athleteNameController = TextEditingController(text: record.athleteName);
      _memoController = TextEditingController(text: record.memo);
      _selectedEventType = record.eventType;
      _recordValue = record.recordValue;
      _measuredDate = record.measuredAt;
      _initialized = true;
    }
  }

  /// 種目マスタが無いときに、記録の単位から型を推測する。
  EventRecordType _inferRecordType(String unit) {
    if (unit == '回') return EventRecordType.count;
    if (unit == 'cm' || unit == 'm' || unit == 'mm' || unit == 'km') {
      return EventRecordType.distance;
    }
    return EventRecordType.time;
  }

  Event? _eventByName(List<Event> events, String? name) {
    for (final event in events) {
      if (event.name == name) return event;
    }
    return null;
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _measuredDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      // 日付だけ差し替え、元の時刻は保つ。
      setState(() {
        _measuredDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _measuredDate.hour,
          _measuredDate.minute,
          _measuredDate.second,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncRecord = ref.watch(_recordForEditProvider(widget.recordId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('記録編集'),
        actions: [
          asyncRecord.maybeWhen(
            data: (record) => record != null
                ? TextButton(
                    onPressed: _isSaving ? null : () => _save(record),
                    child: const Text('保存'),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: asyncRecord.when(
        loading: () => const LoadingState(),
        error: (error, _) => ErrorState(
          message: '記録の読み込みに失敗しました',
          onRetry: () =>
              ref.invalidate(_recordForEditProvider(widget.recordId)),
        ),
        data: (record) {
          if (record == null) {
            return const ErrorState(message: '記録が見つかりません');
          }
          _initControllers(record);
          return _buildForm(context, record);
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context, MeasurementRecord record) {
    final eventState = ref.watch(eventListNotifierProvider);
    final eventOptions = eventState.maybeWhen(
      loaded: (events) => _buildEventOptions(events, record.eventType),
      orElse: () => <String>[record.eventType],
    );
    if (_selectedEventType != null &&
        !eventOptions.contains(_selectedEventType)) {
      _selectedEventType = eventOptions.isEmpty ? null : eventOptions.first;
    }

    final dateText = DateFormat('yyyy/MM/dd').format(_measuredDate);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _athleteNameController,
              decoration: const InputDecoration(
                labelText: '選手名',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              maxLength: AppConstants.maxAthleteNameLength,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '選手名を入力してください';
                }
                if (value.length > AppConstants.maxAthleteNameLength) {
                  return '${AppConstants.maxAthleteNameLength}文字以内で入力してください';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey(_selectedEventType),
              initialValue: _selectedEventType,
              decoration: const InputDecoration(
                labelText: '種目',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.sports),
              ),
              items: eventOptions
                  .map(
                    (eventName) => DropdownMenuItem<String>(
                      value: eventName,
                      child: Text(eventName),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedEventType = value;
                  _recordValue = null;
                });
              },
              validator: (value) => value == null ? '種目を選択してください' : null,
            ),
            const SizedBox(height: 16),
            if (!record.hasVideoReference) ...[
              Builder(
                builder: (context) {
                  final events = eventState.maybeWhen(
                    loaded: (events) => events,
                    orElse: () => const <Event>[],
                  );
                  final event = _eventByName(events, _selectedEventType);
                  final recordType =
                      event?.recordType ??
                      _inferRecordType(record.effectiveRecordUnit);
                  final unit = event?.unit ?? record.effectiveRecordUnit;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '記録値',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      ValueKeypadField(
                        key: ValueKey('$_selectedEventType|$unit'),
                        recordType: recordType,
                        unit: unit,
                        initialValue: _recordValue,
                        onChanged: (value) => _recordValue = value,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
            OutlinedButton.icon(
              onPressed: _selectDate,
              icon: const Icon(Icons.calendar_today),
              label: Text('測定日: $dateText'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _memoController,
              decoration: const InputDecoration(
                labelText: 'メモ',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              maxLength: AppConstants.maxMemoLength,
              validator: (value) {
                if (value != null &&
                    value.length > AppConstants.maxMemoLength) {
                  return '${AppConstants.maxMemoLength}文字以内で入力してください';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSaving ? null : () => _save(record),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _buildEventOptions(List<Event> events, String currentEventType) {
    final names = events.map((event) => event.name).toList();
    if (currentEventType.isNotEmpty && !names.contains(currentEventType)) {
      return [currentEventType, ...names];
    }
    return names;
  }

  Future<void> _save(MeasurementRecord record) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEventType == null || _selectedEventType!.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final isManualRecord = !record.hasVideoReference;
      if (isManualRecord && (_recordValue == null || _recordValue! <= 0)) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('記録値を入力してください')));
          setState(() => _isSaving = false);
        }
        return;
      }
      final events = ref
          .read(eventListNotifierProvider)
          .maybeWhen(loaded: (events) => events, orElse: () => const <Event>[]);
      final recordValue = isManualRecord ? _recordValue : record.recordValue;
      final recordUnit = isManualRecord
          ? (_eventByName(events, _selectedEventType)?.unit ??
                record.effectiveRecordUnit)
          : record.recordUnit;
      final durationMs = isManualRecord
          ? (recordUnit == '秒' ? (recordValue! * 1000).round() : 0)
          : record.durationMs;
      final updated = record.copyWith(
        athleteName: _athleteNameController.text.trim(),
        eventType: _selectedEventType!,
        startMs: isManualRecord ? 0 : record.startMs,
        endMs: isManualRecord ? durationMs : record.endMs,
        durationMs: isManualRecord ? durationMs : record.durationMs,
        recordValue: recordValue,
        recordUnit: recordUnit,
        measuredAt: _measuredDate,
        memo: _memoController.text.trim(),
        updatedAt: DateTime.now(),
      );

      final repository = ref.read(recordRepositoryProvider);
      await repository.updateRecord(updated);
      ref.invalidate(recordListNotifierProvider);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('記録を更新しました')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
