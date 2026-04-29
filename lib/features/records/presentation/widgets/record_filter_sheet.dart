import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:physi_log/features/manage/application/athlete_list_notifier.dart';
import 'package:physi_log/features/manage/application/event_list_notifier.dart';
import 'package:physi_log/features/records/application/record_filter_notifier.dart';
import 'package:physi_log/features/records/domain/record_filter.dart';
import 'package:physi_log/models/athlete.dart';
import 'package:physi_log/models/event.dart';
import 'package:physi_log/models/measurement_record.dart';
import 'package:physi_log/providers/app_providers.dart';

final _recordFilterSourceProvider = FutureProvider<List<MeasurementRecord>>((
  ref,
) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return const <MeasurementRecord>[];
  }
  final repository = ref.watch(recordRepositoryProvider);
  return repository.getRecords(userId: userId, limit: 1000);
});

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
  String? _selectedAthleteId;
  String? _selectedEventType;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  RecordSortKey _sortKey = RecordSortKey.measuredAtDesc;

  @override
  void initState() {
    super.initState();
    final filter = ref.read(recordFilterNotifierProvider);
    _selectedAthleteId = filter.athleteId;
    _selectedEventType = filter.eventType;
    _dateFrom = filter.dateFrom;
    _dateTo = filter.dateTo;
    _sortKey = filter.sortKey;
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd');
    final athleteState = ref.watch(athleteListNotifierProvider);
    final eventState = ref.watch(eventListNotifierProvider);
    final sourceState = ref.watch(_recordFilterSourceProvider);
    final athletes = athleteState.maybeWhen(
      loaded: (athletes) => athletes,
      orElse: () => const <Athlete>[],
    );
    final events = eventState.maybeWhen(
      loaded: (events) => events,
      orElse: () => const <Event>[],
    );
    final sourceRecords = sourceState.maybeWhen(
      data: (records) => records,
      orElse: () => const <MeasurementRecord>[],
    );
    final availableEventTypes = _resolveAvailableEventTypes(
      athletes: athletes,
      events: events,
      records: sourceRecords,
      selectedAthleteId: _selectedAthleteId,
    );

    if (_selectedEventType != null &&
        !availableEventTypes.contains(_selectedEventType)) {
      _selectedEventType = null;
    }

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
              DropdownButtonFormField<String>(
                initialValue: _selectedAthleteId,
                decoration: const InputDecoration(
                  labelText: '選手',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('すべて'),
                  ),
                  ...athletes.map(
                    (athlete) => DropdownMenuItem<String>(
                      value: athlete.id,
                      child: Text(athlete.name),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedAthleteId = value;
                    _selectedEventType = null;
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedEventType,
                decoration: const InputDecoration(
                  labelText: '種目',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.sports),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('すべて'),
                  ),
                  ...availableEventTypes.map(
                    (eventType) => DropdownMenuItem<String>(
                      value: eventType,
                      child: Text(eventType),
                    ),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _selectedEventType = value),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _selectDate(isFrom: true),
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(
                        _dateFrom != null
                            ? dateFormat.format(_dateFrom!)
                            : '開始日',
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
              FilledButton(onPressed: _applyFilter, child: const Text('適用')),
            ],
          ),
        );
      },
    );
  }

  List<String> _resolveAvailableEventTypes({
    required List<Athlete> athletes,
    required List<Event> events,
    required List<MeasurementRecord> records,
    required String? selectedAthleteId,
  }) {
    final allEventTypes = events.map((event) => event.name).toSet().toList()
      ..sort();
    if (selectedAthleteId == null) {
      return allEventTypes;
    }

    String? athleteName;
    for (final athlete in athletes) {
      if (athlete.id == selectedAthleteId) {
        athleteName = athlete.name;
        break;
      }
    }

    final eventTypes =
        records
            .where((record) {
              if (record.athleteId != null && record.athleteId!.isNotEmpty) {
                return record.athleteId == selectedAthleteId;
              }
              return athleteName != null && record.athleteName == athleteName;
            })
            .map((record) => record.eventType)
            .where((eventType) => eventType.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    if (eventTypes.isEmpty) {
      return allEventTypes;
    }
    return eventTypes;
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
      _selectedAthleteId = null;
      _selectedEventType = null;
      _dateFrom = null;
      _dateTo = null;
      _sortKey = RecordSortKey.measuredAtDesc;
    });
  }

  void _applyFilter() {
    final notifier = ref.read(recordFilterNotifierProvider.notifier);
    if (_selectedAthleteId == null) {
      notifier.setAthleteName(null);
    } else {
      final athletes = ref
          .read(athleteListNotifierProvider)
          .maybeWhen(
            loaded: (athletes) => athletes,
            orElse: () => const <Athlete>[],
          );
      Athlete? selectedAthlete;
      for (final athlete in athletes) {
        if (athlete.id == _selectedAthleteId) {
          selectedAthlete = athlete;
          break;
        }
      }
      notifier.setAthlete(
        athleteId: _selectedAthleteId,
        athleteName: selectedAthlete?.name,
      );
    }
    notifier.setEventType(_selectedEventType);
    notifier.setDateRange(_dateFrom, _dateTo);
    notifier.setSortKey(_sortKey);
    Navigator.pop(context);
  }
}
