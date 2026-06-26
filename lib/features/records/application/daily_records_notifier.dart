import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:physi_log/features/manage/domain/event_repository.dart';
import 'package:physi_log/features/records/application/record_filter_notifier.dart';
import 'package:physi_log/features/records/application/record_list_notifier.dart';
import 'package:physi_log/features/records/domain/record_filter.dart';
import 'package:physi_log/features/records/domain/record_repository.dart';
import 'package:physi_log/models/event.dart';
import 'package:physi_log/models/measurement_record.dart';
import 'package:physi_log/providers/app_providers.dart';

part 'daily_records_notifier.freezed.dart';

/// 日別シートの1セルぶんの値。
class DailyCell {
  const DailyCell({
    required this.recordId,
    required this.value,
    required this.displayText,
    required this.isPersonalBest,
  });

  /// このセルが表す記録のID（タップで編集・削除するのに使う）。
  final String recordId;
  final double value;
  final String displayText;

  /// この値が、その選手・その種目の全期間ベストと一致するか。
  final bool isPersonalBest;
}

/// 日別シートの列（種目）。
class DailyEventColumn {
  const DailyEventColumn({
    required this.key,
    required this.name,
    required this.recordType,
  });

  final String key;
  final String name;
  final EventRecordType recordType;
}

/// 日別シートの行（選手）。
class DailyAthleteRow {
  const DailyAthleteRow({
    required this.key,
    required this.name,
    required this.cells,
  });

  final String key;
  final String name;

  /// 種目key -> セル。未計測の種目は欠損。
  final Map<String, DailyCell> cells;
}

/// 1日ぶんの計測会。
class DailySession {
  const DailySession({
    required this.date,
    required this.columns,
    required this.rows,
  });

  final DateTime date;
  final List<DailyEventColumn> columns;
  final List<DailyAthleteRow> rows;

  int get athleteCount => rows.length;
}

@freezed
class DailyRecordsState with _$DailyRecordsState {
  const factory DailyRecordsState.loading() = _Loading;
  const factory DailyRecordsState.loaded({
    required List<DailySession> sessions,
    required int selectedIndex,
  }) = _Loaded;
  const factory DailyRecordsState.error(String message) = _Error;
}

String _athleteKey(MeasurementRecord record) {
  final id = record.athleteId;
  if (id != null && id.isNotEmpty) return 'id:$id';
  return 'name:${record.athleteName}';
}

String _eventKey(MeasurementRecord record) {
  final id = record.eventId;
  if (id != null && id.isNotEmpty) return 'id:$id';
  return 'name:${record.eventType}';
}

DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

/// 種目マスタに残っていない記録（削除済み種目など）の記録の型を、
/// 記録の単位から推測する。秒→タイム / cm→距離 / 回→回数。
EventRecordType _inferRecordTypeFromUnit(String? unit) {
  final normalized = unit?.trim();
  for (final type in EventRecordType.values) {
    if (type.defaultUnit == normalized) return type;
  }
  return EventRecordType.time;
}

/// 記録と種目マスタから、日別の計測会リスト（新しい順）を組み立てる純粋関数。
List<DailySession> buildDailySessions(
  List<MeasurementRecord> records,
  List<Event> events,
) {
  if (records.isEmpty) return const [];

  // 種目マスタ（id / 名前 で引けるように）と並び順。
  final eventById = <String, Event>{};
  final eventByName = <String, Event>{};
  for (final event in events) {
    eventById[event.id] = event;
    eventByName[event.name] = event;
  }

  EventRecordType recordTypeOf(MeasurementRecord record) {
    final byId = record.eventId == null ? null : eventById[record.eventId];
    final event = byId ?? eventByName[record.eventType];
    if (event != null) return event.recordType;
    return _inferRecordTypeFromUnit(record.effectiveRecordUnit);
  }

  int eventSortOrderOf(MeasurementRecord record) {
    final byId = record.eventId == null ? null : eventById[record.eventId];
    final event = byId ?? eventByName[record.eventType];
    return event?.sortOrder ?? 1 << 30;
  }

  // 全期間ベスト（選手key + 種目key -> 最良値）。PB判定に使う。
  final allTimeBest = <String, double>{};
  for (final record in records) {
    final key = '${_athleteKey(record)}|${_eventKey(record)}';
    final value = record.effectiveRecordValue;
    final lowerIsBetter = recordTypeOf(record).lowerIsBetter;
    final current = allTimeBest[key];
    if (current == null ||
        (lowerIsBetter ? value < current : value > current)) {
      allTimeBest[key] = value;
    }
  }

  // 日付ごとにグルーピング。
  final byDate = <DateTime, List<MeasurementRecord>>{};
  for (final record in records) {
    final date = _dateOnly(record.measuredAt);
    byDate.putIfAbsent(date, () => []).add(record);
  }

  final dates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));

  final sessions = <DailySession>[];
  for (final date in dates) {
    final dayRecords = byDate[date]!;

    // 列（種目）：登場順を保ちつつ、sortOrder→名前 で並べる。
    final columnByKey = <String, DailyEventColumn>{};
    final sortOrderByKey = <String, int>{};
    for (final record in dayRecords) {
      final key = _eventKey(record);
      sortOrderByKey[key] = eventSortOrderOf(record);
      columnByKey.putIfAbsent(
        key,
        () => DailyEventColumn(
          key: key,
          name: record.eventType.isEmpty ? '未設定' : record.eventType,
          recordType: recordTypeOf(record),
        ),
      );
    }
    final columns = columnByKey.values.toList()
      ..sort((a, b) {
        final orderA = sortOrderByKey[a.key]!;
        final orderB = sortOrderByKey[b.key]!;
        if (orderA != orderB) return orderA.compareTo(orderB);
        return a.name.compareTo(b.name);
      });

    // 行（選手）：選手key -> 種目key -> その日のベスト記録。
    final rowOrder = <String>[];
    final nameByKey = <String, String>{};
    final dayBest = <String, Map<String, MeasurementRecord>>{};
    for (final record in dayRecords) {
      final aKey = _athleteKey(record);
      final eKey = _eventKey(record);
      if (!dayBest.containsKey(aKey)) {
        dayBest[aKey] = {};
        rowOrder.add(aKey);
        final name = record.athleteName;
        nameByKey[aKey] = name.isEmpty ? '未登録' : name;
      }
      final existing = dayBest[aKey]![eKey];
      final lowerIsBetter = recordTypeOf(record).lowerIsBetter;
      if (existing == null) {
        dayBest[aKey]![eKey] = record;
      } else {
        final cur = existing.effectiveRecordValue;
        final val = record.effectiveRecordValue;
        final better = lowerIsBetter ? val < cur : val > cur;
        if (better) dayBest[aKey]![eKey] = record;
      }
    }

    rowOrder.sort((a, b) => nameByKey[a]!.compareTo(nameByKey[b]!));

    final rows = <DailyAthleteRow>[];
    for (final aKey in rowOrder) {
      final cells = <String, DailyCell>{};
      dayBest[aKey]!.forEach((eKey, record) {
        final value = record.effectiveRecordValue;
        final best = allTimeBest['$aKey|$eKey'];
        final isPb = best == null || (value - best).abs() < 1e-9;
        cells[eKey] = DailyCell(
          recordId: record.id,
          value: value,
          displayText: record.formattedRecordValue,
          isPersonalBest: isPb,
        );
      });
      rows.add(
        DailyAthleteRow(key: aKey, name: nameByKey[aKey]!, cells: cells),
      );
    }

    sessions.add(DailySession(date: date, columns: columns, rows: rows));
  }

  return sessions;
}

final dailyRecordsNotifierProvider =
    StateNotifierProvider<DailyRecordsNotifier, DailyRecordsState>((ref) {
      final recordRepository = ref.watch(recordRepositoryProvider);
      final eventRepository = ref.watch(eventRepositoryProvider);
      final userId = ref.watch(currentUserIdProvider);
      final filter = ref.watch(recordFilterNotifierProvider);
      final notifier = DailyRecordsNotifier(
        recordRepository: recordRepository,
        eventRepository: eventRepository,
        userId: userId,
        filter: filter,
      );
      // 記録一覧が更新されたら、日別ビューも最新データへ追従して再読み込みする。
      ref.listen<RecordListState>(recordListNotifierProvider, (_, _) {
        notifier.refresh();
      });
      return notifier;
    });

class DailyRecordsNotifier extends StateNotifier<DailyRecordsState> {
  DailyRecordsNotifier({
    required RecordRepository recordRepository,
    required EventRepository eventRepository,
    required String? userId,
    required RecordFilter filter,
  }) : _recordRepository = recordRepository,
       _eventRepository = eventRepository,
       _userId = userId,
       _filter = filter,
       super(const DailyRecordsState.loading()) {
    load();
  }

  final RecordRepository _recordRepository;
  final EventRepository _eventRepository;
  final String? _userId;
  final RecordFilter _filter;

  Future<void> load() async {
    final userId = _userId;
    if (userId == null) {
      state = const DailyRecordsState.loaded(sessions: [], selectedIndex: 0);
      return;
    }

    state = const DailyRecordsState.loading();
    try {
      final records = await _recordRepository.getAllRecords(userId: userId);
      // 削除済み種目も含めて取得し、過去記録でも正規の recordType を参照できる
      // ようにする（単位推測に頼らずベスト判定方向を正しくするため）。
      final events = await _eventRepository.getEvents(
        userId: userId,
        includeDeleted: true,
      );
      // 記録一覧と同じ絞り込み条件（選手・種目・期間）を日別ビューにも反映する。
      final filtered = _applyFilter(records);
      final sessions = buildDailySessions(filtered, events);
      state = DailyRecordsState.loaded(sessions: sessions, selectedIndex: 0);
    } catch (e) {
      state = DailyRecordsState.error('記録の読み込みに失敗しました: $e');
    }
  }

  Future<void> refresh() => load();

  /// 記録フィルター（選手・種目・期間）を適用する。
  List<MeasurementRecord> _applyFilter(List<MeasurementRecord> records) {
    final filter = _filter;
    return records.where((r) {
      if (filter.athleteId != null && filter.athleteId!.isNotEmpty) {
        if (r.athleteId != filter.athleteId) return false;
      }
      if (filter.athleteName != null && filter.athleteName!.isNotEmpty) {
        if (!r.athleteName.contains(filter.athleteName!)) return false;
      }
      if (filter.eventType != null && filter.eventType!.isNotEmpty) {
        if (r.eventType != filter.eventType) return false;
      }
      if (filter.dateFrom != null && r.measuredAt.isBefore(filter.dateFrom!)) {
        return false;
      }
      if (filter.dateTo != null) {
        final end = filter.dateTo!.add(const Duration(days: 1));
        if (r.measuredAt.isAfter(end)) return false;
      }
      return true;
    }).toList();
  }

  /// 表示中の計測会を1つ前（より新しい日）に移す。
  void moveToNewer() => _moveTo(-1);

  /// 表示中の計測会を1つ後（より古い日）に移す。
  void moveToOlder() => _moveTo(1);

  void selectIndex(int index) {
    final current = state;
    if (current is! _Loaded) return;
    if (index < 0 || index >= current.sessions.length) return;
    state = current.copyWith(selectedIndex: index);
  }

  void _moveTo(int delta) {
    final current = state;
    if (current is! _Loaded) return;
    final next = current.selectedIndex + delta;
    if (next < 0 || next >= current.sessions.length) return;
    state = current.copyWith(selectedIndex: next);
  }
}
