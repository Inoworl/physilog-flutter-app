import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:physi_log/app/theme/app_colors.dart';

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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('この機能は準備中です')),
    );
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
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  '手動記録',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xl),

                // 選手名
                TextFormField(
                  controller: _athleteNameController,
                  decoration: const InputDecoration(
                    labelText: '選手名',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '選手名を入力してください';
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
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
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
                ),
                const SizedBox(height: AppSpacing.xl),

                // 記録ボタン
                FilledButton(
                  onPressed: _submit,
                  child: const Text('記録する'),
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
