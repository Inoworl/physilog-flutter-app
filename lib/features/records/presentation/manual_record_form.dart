import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:physi_log/app/theme/app_colors.dart';
import 'package:physi_log/features/manage/application/athlete_list_notifier.dart';
import 'package:physi_log/features/manage/application/event_list_notifier.dart';
import 'package:physi_log/features/records/application/record_list_notifier.dart';
import 'package:physi_log/features/records/presentation/widgets/value_keypad_field.dart';
import 'package:physi_log/models/athlete.dart';
import 'package:physi_log/models/event.dart';
import 'package:physi_log/models/measurement_record.dart';
import 'package:physi_log/providers/app_providers.dart';
import 'package:physi_log/shared/constants/app_constants.dart';
import 'package:uuid/uuid.dart';

class ManualRecordForm extends ConsumerStatefulWidget {
  const ManualRecordForm({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const ManualRecordForm(),
    );
  }

  @override
  ConsumerState<ManualRecordForm> createState() => _ManualRecordFormState();
}

class _ManualRecordFormState extends ConsumerState<ManualRecordForm> {
  final _formKey = GlobalKey<FormState>();
  final _memoController = TextEditingController();
  DateTime _measuredDate = DateTime.now();
  String? _selectedAthleteId;
  String? _selectedEventId;
  double? _recordValue;
  bool _isSaving = false;

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _measuredDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _measuredDate = picked);
    }
  }

  Athlete? _findSelectedAthlete(List<Athlete> athletes) {
    final selectedId = _selectedAthleteId;
    if (selectedId == null) return null;

    for (final athlete in athletes) {
      if (athlete.id == selectedId) {
        return athlete;
      }
    }
    return null;
  }

  Event? _findSelectedEvent(List<Event> events) {
    final selectedId = _selectedEventId;
    if (selectedId == null) return null;

    for (final event in events) {
      if (event.id == selectedId) {
        return event;
      }
    }
    return null;
  }

  Future<void> _submit(List<Athlete> athletes, List<Event> events) async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Firebase認証待機中です。少し待って再実行してください。')),
      );
      return;
    }

    final selectedAthlete = _findSelectedAthlete(athletes);
    if (selectedAthlete == null) {
      messenger.showSnackBar(const SnackBar(content: Text('選手を選択してください')));
      return;
    }
    final selectedEvent = _findSelectedEvent(events);
    if (selectedEvent == null) {
      messenger.showSnackBar(const SnackBar(content: Text('種目を選択してください')));
      return;
    }

    final recordValue = _recordValue;
    if (recordValue == null || recordValue <= 0) {
      messenger.showSnackBar(const SnackBar(content: Text('記録値を入力してください')));
      return;
    }
    final recordUnit = selectedEvent.unit;
    final durationMs = recordUnit == '秒' ? (recordValue * 1000).round() : 0;
    final now = DateTime.now();
    final measuredAt = DateTime(
      _measuredDate.year,
      _measuredDate.month,
      _measuredDate.day,
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
      now.microsecond,
    );

    setState(() => _isSaving = true);

    try {
      final record = MeasurementRecord(
        id: const Uuid().v4(),
        userId: userId,
        athleteId: selectedAthlete.id,
        eventId: selectedEvent.id,
        athleteName: selectedAthlete.name,
        eventType: selectedEvent.name,
        startMs: 0,
        endMs: durationMs,
        durationMs: durationMs,
        recordValue: recordValue,
        recordUnit: recordUnit,
        measuredAt: measuredAt,
        memo: _memoController.text.trim(),
        createdAt: now,
        updatedAt: now,
      );

      await ref.read(recordRepositoryProvider).saveRecord(record);
      ref.invalidate(recordListNotifierProvider);

      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('手動記録を保存しました')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd');
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final athleteState = ref.watch(athleteListNotifierProvider);
    final eventState = ref.watch(eventListNotifierProvider);
    final athletes = athleteState.maybeWhen(
      loaded: (athletes) => athletes,
      orElse: () => const <Athlete>[],
    );
    final events = eventState.maybeWhen(
      loaded: (events) => events,
      orElse: () => const <Event>[],
    );

    if (_selectedAthleteId == null && athletes.isNotEmpty) {
      _selectedAthleteId = athletes.first.id;
    }
    if (_selectedEventId == null && events.isNotEmpty) {
      _selectedEventId = events.first.id;
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Form(
            key: _formKey,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              children: [
                Center(
                  child: Container(
                    width: 32,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text('手動記録', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.xl),
                if (athletes.isEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('選手が未登録です。管理タブで選手を登録してください。'),
                  ),
                ] else ...[
                  DropdownButtonFormField<String>(
                    key: ValueKey(_selectedAthleteId),
                    initialValue: _selectedAthleteId,
                    decoration: const InputDecoration(
                      labelText: '選手',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    items: athletes
                        .map(
                          (athlete) => DropdownMenuItem<String>(
                            value: athlete.id,
                            child: Text(athlete.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedAthleteId = value);
                    },
                    validator: (value) => value == null ? '選手を選択してください' : null,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                if (events.isEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('種目が未登録です。管理タブで種目を登録してください。'),
                  ),
                ] else ...[
                  DropdownButtonFormField<String>(
                    key: ValueKey(_selectedEventId),
                    initialValue: _selectedEventId,
                    decoration: const InputDecoration(
                      labelText: '種目',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.sports),
                    ),
                    items: events
                        .map(
                          (event) => DropdownMenuItem<String>(
                            value: event.id,
                            child: Text(event.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedEventId = value;
                        _recordValue = null;
                      });
                    },
                    validator: (value) => value == null ? '種目を選択してください' : null,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                if (_findSelectedEvent(events) case final selectedEvent?) ...[
                  Text('記録値', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.sm),
                  ValueKeypadField(
                    key: ValueKey(selectedEvent.id),
                    recordType: selectedEvent.recordType,
                    unit: selectedEvent.unit,
                    onChanged: (value) => _recordValue = value,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton.icon(
                  onPressed: _selectDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text('測定日: ${dateFormat.format(_measuredDate)}'),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _memoController,
                  decoration: const InputDecoration(
                    labelText: 'メモ',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note),
                  ),
                  maxLines: 3,
                  maxLength: AppConstants.maxMemoLength,
                  validator: (value) {
                    if (value != null &&
                        value.length > AppConstants.maxMemoLength) {
                      return '${AppConstants.maxMemoLength}文字以内で入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  onPressed: _isSaving || athletes.isEmpty || events.isEmpty
                      ? null
                      : () => _submit(athletes, events),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('記録する'),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          );
        },
      ),
    );
  }
}
