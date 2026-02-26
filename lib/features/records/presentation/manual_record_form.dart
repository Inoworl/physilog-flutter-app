import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:physi_log/app/theme/app_colors.dart';
import 'package:physi_log/features/records/application/record_list_notifier.dart';
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
  final _athleteNameController = TextEditingController();
  final _eventTypeController = TextEditingController();
  final _timeController = TextEditingController();
  final _memoController = TextEditingController();
  DateTime _measuredDate = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _athleteNameController.dispose();
    _eventTypeController.dispose();
    _timeController.dispose();
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final userId = ref.read(currentUserIdProvider) ?? 'local-user';
    final seconds = double.parse(
      _timeController.text.trim().replaceAll(',', '.'),
    );
    final durationMs = (seconds * 1000).round();
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
        athleteName: _athleteNameController.text.trim(),
        eventType: _eventTypeController.text.trim(),
        startMs: 0,
        endMs: durationMs,
        durationMs: durationMs,
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

                // 選手名
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
                const SizedBox(height: AppSpacing.lg),

                // 種目
                TextFormField(
                  controller: _eventTypeController,
                  decoration: const InputDecoration(
                    labelText: '種目',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.sports),
                  ),
                  maxLength: AppConstants.maxEventTypeLength,
                  validator: (value) {
                    if (value != null &&
                        value.length > AppConstants.maxEventTypeLength) {
                      return '${AppConstants.maxEventTypeLength}文字以内で入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // タイム
                TextFormField(
                  controller: _timeController,
                  decoration: const InputDecoration(
                    labelText: 'タイム（秒）',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.timer),
                    hintText: '例: 12.34',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'タイムを入力してください';
                    }
                    final parsed = double.tryParse(
                      value.trim().replaceAll(',', '.'),
                    );
                    if (parsed == null) {
                      return 'タイムは数値で入力してください';
                    }
                    if (parsed <= 0) {
                      return 'タイムは0より大きい値を入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // 測定日
                OutlinedButton.icon(
                  onPressed: _selectDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text('測定日: ${dateFormat.format(_measuredDate)}'),
                ),
                const SizedBox(height: AppSpacing.lg),

                // メモ
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

                // 記録ボタン
                FilledButton(
                  onPressed: _isSaving ? null : _submit,
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
