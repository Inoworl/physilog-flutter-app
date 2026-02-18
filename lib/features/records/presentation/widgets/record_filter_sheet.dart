import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:physi_log/features/records/application/record_filter_notifier.dart';
import 'package:physi_log/features/records/domain/record_filter.dart';
import 'package:physi_log/shared/constants/app_constants.dart';

class RecordFilterSheet extends ConsumerStatefulWidget {
  const RecordFilterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const RecordFilterSheet(),
    );
  }

  @override
  ConsumerState<RecordFilterSheet> createState() => _RecordFilterSheetState();
}

class _RecordFilterSheetState extends ConsumerState<RecordFilterSheet> {
  late TextEditingController _athleteNameController;
  String? _selectedEventType;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  RecordSortKey _sortKey = RecordSortKey.measuredAtDesc;

  @override
  void initState() {
    super.initState();
    final filter = ref.read(recordFilterNotifierProvider);
    _athleteNameController = TextEditingController(text: filter.athleteName ?? '');
    _selectedEventType = filter.eventType;
    _dateFrom = filter.dateFrom;
    _dateTo = filter.dateTo;
    _sortKey = filter.sortKey;
  }

  @override
  void dispose() {
    _athleteNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd');

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              // ヘッダー
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('フィルタ', style: Theme.of(context).textTheme.titleLarge),
                  TextButton(
                    onPressed: _resetFilter,
                    child: const Text('リセット'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 選手名
              TextField(
                controller: _athleteNameController,
                decoration: const InputDecoration(
                  labelText: '選手名',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),

              // 種目
              DropdownButtonFormField<String>(
                initialValue: _selectedEventType,
                decoration: const InputDecoration(
                  labelText: '種目',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.sports),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('すべて')),
                  ...AppConstants.eventSuggestions.map(
                    (e) => DropdownMenuItem(value: e, child: Text(e)),
                  ),
                ],
                onChanged: (value) => setState(() => _selectedEventType = value),
              ),
              const SizedBox(height: 16),

              // 日付範囲
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _selectDate(isFrom: true),
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(
                        _dateFrom != null ? dateFormat.format(_dateFrom!) : '開始日',
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('〜'),
                  ),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _selectDate(isFrom: false),
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(
                        _dateTo != null ? dateFormat.format(_dateTo!) : '終了日',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ソート順
              Text('並び順', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: RecordSortKey.values.map((key) {
                  return ChoiceChip(
                    label: Text(key.label),
                    selected: _sortKey == key,
                    onSelected: (selected) {
                      if (selected) setState(() => _sortKey = key);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // 適用ボタン
              FilledButton(
                onPressed: _applyFilter,
                child: const Text('適用'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectDate({required bool isFrom}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _dateFrom : _dateTo) ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _dateFrom = picked;
        } else {
          _dateTo = picked;
        }
      });
    }
  }

  void _resetFilter() {
    setState(() {
      _athleteNameController.clear();
      _selectedEventType = null;
      _dateFrom = null;
      _dateTo = null;
      _sortKey = RecordSortKey.measuredAtDesc;
    });
  }

  void _applyFilter() {
    final notifier = ref.read(recordFilterNotifierProvider.notifier);
    notifier.setAthleteName(
      _athleteNameController.text.isEmpty ? null : _athleteNameController.text,
    );
    notifier.setEventType(_selectedEventType);
    notifier.setDateRange(_dateFrom, _dateTo);
    notifier.setSortKey(_sortKey);
    Navigator.pop(context);
  }
}
