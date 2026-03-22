import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:physi_log/features/records/application/record_list_notifier.dart';
import 'package:physi_log/providers/app_providers.dart';
import 'package:physi_log/models/measurement_record.dart';
import 'package:physi_log/shared/constants/app_constants.dart';
import 'package:physi_log/shared/widgets/error_state.dart';
import 'package:physi_log/shared/widgets/loading_state.dart';

final _recordForEditProvider =
    FutureProvider.family<MeasurementRecord?, String>((ref, id) async {
      final repository = ref.watch(recordRepositoryProvider);
      return repository.getRecord(id);
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
  late TextEditingController _eventTypeController;
  late TextEditingController _memoController;
  bool _initialized = false;
  bool _isSaving = false;

  @override
  void dispose() {
    if (_initialized) {
      _athleteNameController.dispose();
      _eventTypeController.dispose();
      _memoController.dispose();
    }
    super.dispose();
  }

  void _initControllers(MeasurementRecord record) {
    if (!_initialized) {
      _athleteNameController = TextEditingController(text: record.athleteName);
      _eventTypeController = TextEditingController(text: record.eventType);
      _memoController = TextEditingController(text: record.memo);
      _initialized = true;
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
          return _buildForm(context);
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            const SizedBox(height: 16),

            // 種目
            Autocomplete<String>(
              initialValue: _eventTypeController.value,
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return AppConstants.eventSuggestions;
                }
                return AppConstants.eventSuggestions.where(
                  (e) => e.contains(textEditingValue.text),
                );
              },
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                // Sync with our controller
                controller.addListener(() {
                  _eventTypeController.text = controller.text;
                });
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: '種目',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.sports),
                  ),
                  maxLength: AppConstants.maxEventTypeLength,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '種目を入力してください';
                    }
                    return null;
                  },
                );
              },
              onSelected: (value) {
                _eventTypeController.text = value;
              },
            ),
            const SizedBox(height: 16),

            // メモ
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

            // 保存ボタン
            FilledButton(
              onPressed: _isSaving
                  ? null
                  : () {
                      final record = ref
                          .read(_recordForEditProvider(widget.recordId))
                          .valueOrNull;
                      if (record != null) _save(record);
                    },
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

  Future<void> _save(MeasurementRecord record) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final updated = record.copyWith(
        athleteName: _athleteNameController.text.trim(),
        eventType: _eventTypeController.text.trim(),
        memo: _memoController.text.trim(),
        updatedAt: DateTime.now(),
      );

      final repository = ref.read(recordRepositoryProvider);
      await repository.updateRecord(updated);

      // 一覧をリフレッシュ
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
