import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/manage/domain/event_repository.dart';
import 'package:physi_log/features/records/application/daily_records_notifier.dart';
import 'package:physi_log/features/records/application/record_filter_notifier.dart';
import 'package:physi_log/features/records/application/record_list_notifier.dart';
import 'package:physi_log/features/records/domain/record_filter.dart';
import 'package:physi_log/features/records/domain/record_repository.dart';
import 'package:physi_log/models/event.dart';
import 'package:physi_log/models/measurement_record.dart';
import 'package:physi_log/providers/app_providers.dart';

MeasurementRecord _rec({
  required String id,
  required String athleteId,
  required String athleteName,
  required String eventId,
  required String eventType,
  required double value,
  required String unit,
  required DateTime measuredAt,
}) {
  return MeasurementRecord(
    id: id,
    userId: 'u1',
    athleteId: athleteId,
    athleteName: athleteName,
    eventId: eventId,
    eventType: eventType,
    startMs: 0,
    endMs: 0,
    durationMs: 0,
    recordValue: value,
    recordUnit: unit,
    measuredAt: measuredAt,
    createdAt: measuredAt,
    updatedAt: measuredAt,
  );
}

Event _event({
  required String id,
  required String name,
  required EventRecordType type,
  required int sortOrder,
}) {
  final now = DateTime(2026, 1, 1);
  return Event(
    id: id,
    userId: 'u1',
    name: name,
    unit: type.defaultUnit,
    recordType: type,
    measurementMethod: type.defaultMeasurementMethod,
    sortOrder: sortOrder,
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeRecordRepository implements RecordRepository {
  _FakeRecordRepository(this.records);

  final List<MeasurementRecord> records;

  @override
  Future<List<MeasurementRecord>> getRecords({
    required String userId,
    RecordFilter? filter,
    int limit = 20,
    MeasurementRecord? lastRecord,
  }) async {
    return records.where((record) => record.userId == userId).toList();
  }

  @override
  Future<List<MeasurementRecord>> getAllRecords({
    required String userId,
  }) async {
    return records.where((record) => record.userId == userId).toList();
  }

  @override
  Future<MeasurementRecord?> getRecord({
    required String userId,
    required String id,
  }) async {
    for (final record in records) {
      if (record.userId == userId && record.id == id) return record;
    }
    return null;
  }

  @override
  Future<void> saveRecord(MeasurementRecord record) async {
    records.add(record);
  }

  @override
  Future<void> updateRecord(MeasurementRecord record) async {
    final index = records.indexWhere((item) => item.id == record.id);
    if (index != -1) records[index] = record;
  }

  @override
  Future<void> deleteRecord({
    required String userId,
    required String id,
  }) async {
    records.removeWhere((record) => record.userId == userId && record.id == id);
  }
}

class _FakeEventRepository implements EventRepository {
  _FakeEventRepository(this.events);

  final List<Event> events;

  @override
  Future<List<Event>> getEvents({
    required String userId,
    bool includeDeleted = false,
  }) async {
    return events
        .where((event) => event.userId == userId)
        .where((event) => includeDeleted || event.deletedAt == null)
        .toList();
  }

  @override
  Future<void> saveEvent(Event event) async {
    events.add(event);
  }

  @override
  Future<void> updateEvent(Event event) async {
    final index = events.indexWhere((item) => item.id == event.id);
    if (index != -1) events[index] = event;
  }

  @override
  Future<void> deleteEvent({required String userId, required String id}) async {
    events.removeWhere((event) => event.userId == userId && event.id == id);
  }
}

Future<DailyRecordsState> _waitForDailyLoaded(
  ProviderContainer container,
) async {
  for (var i = 0; i < 20; i++) {
    final state = container.read(dailyRecordsNotifierProvider);
    final isLoading = state.maybeWhen(loading: () => true, orElse: () => false);
    if (!isLoading) return state;
    await Future<void>.delayed(Duration.zero);
  }
  return container.read(dailyRecordsNotifierProvider);
}

Future<RecordListState> _waitForRecordListLoaded(
  ProviderContainer container,
) async {
  for (var i = 0; i < 20; i++) {
    final state = container.read(recordListNotifierProvider);
    final isLoading = state.maybeWhen(loading: () => true, orElse: () => false);
    if (!isLoading) return state;
    await Future<void>.delayed(Duration.zero);
  }
  return container.read(recordListNotifierProvider);
}

void main() {
  final events = [
    _event(id: 'e50', name: '50m', type: EventRecordType.time, sortOrder: 1),
    _event(
      id: 'ehj',
      name: '立ち幅跳び',
      type: EventRecordType.distance,
      sortOrder: 2,
    ),
  ];

  final day1 = DateTime(2026, 6, 12, 10);
  final day2 = DateTime(2026, 5, 30, 10);

  test('記録が空ならセッションも空', () {
    expect(buildDailySessions([], events), isEmpty);
  });

  test('日付ごとに新しい順でグルーピングされる', () {
    final records = [
      _rec(
        id: 'r1',
        athleteId: 'a1',
        athleteName: 'たろう',
        eventId: 'e50',
        eventType: '50m',
        value: 7.41,
        unit: '秒',
        measuredAt: day2,
      ),
      _rec(
        id: 'r2',
        athleteId: 'a1',
        athleteName: 'たろう',
        eventId: 'e50',
        eventType: '50m',
        value: 7.21,
        unit: '秒',
        measuredAt: day1,
      ),
    ];

    final sessions = buildDailySessions(records, events);

    expect(sessions, hasLength(2));
    expect(sessions.first.date, DateTime(2026, 6, 12));
    expect(sessions[1].date, DateTime(2026, 5, 30));
  });

  test('行=選手・列=種目で、未計測の種目は欠損する', () {
    final records = [
      _rec(
        id: 'r1',
        athleteId: 'a1',
        athleteName: 'たろう',
        eventId: 'e50',
        eventType: '50m',
        value: 7.21,
        unit: '秒',
        measuredAt: day1,
      ),
      _rec(
        id: 'r2',
        athleteId: 'a1',
        athleteName: 'たろう',
        eventId: 'ehj',
        eventType: '立ち幅跳び',
        value: 230,
        unit: 'cm',
        measuredAt: day1,
      ),
      _rec(
        id: 'r3',
        athleteId: 'a2',
        athleteName: 'じろう',
        eventId: 'e50',
        eventType: '50m',
        value: 7.35,
        unit: '秒',
        measuredAt: day1,
      ),
    ];

    final session = buildDailySessions(records, events).single;

    // 列は sortOrder 順
    expect(session.columns.map((c) => c.name).toList(), ['50m', '立ち幅跳び']);
    // 行は選手名順
    expect(session.rows.map((r) => r.name).toList(), ['じろう', 'たろう']);

    final taro = session.rows.firstWhere((r) => r.name == 'たろう');
    expect(taro.cells.containsKey('id:e50'), isTrue);
    expect(taro.cells.containsKey('id:ehj'), isTrue);

    final jiro = session.rows.firstWhere((r) => r.name == 'じろう');
    // じろうは立ち幅跳び未計測 → 欠損
    expect(jiro.cells.containsKey('id:ehj'), isFalse);
  });

  test('同日同選手同種目が複数なら、タイムは速い方を採用する', () {
    final records = [
      _rec(
        id: 'r1',
        athleteId: 'a1',
        athleteName: 'たろう',
        eventId: 'e50',
        eventType: '50m',
        value: 7.30,
        unit: '秒',
        measuredAt: day1,
      ),
      _rec(
        id: 'r2',
        athleteId: 'a1',
        athleteName: 'たろう',
        eventId: 'e50',
        eventType: '50m',
        value: 7.21,
        unit: '秒',
        measuredAt: day1,
      ),
    ];

    final session = buildDailySessions(records, events).single;
    final taro = session.rows.single;
    expect(taro.cells['id:e50']!.value, 7.21);
  });

  test('全期間ベストのセルに自己ベストフラグが立つ（タイムは小さい方）', () {
    final records = [
      _rec(
        id: 'r1',
        athleteId: 'a1',
        athleteName: 'たろう',
        eventId: 'e50',
        eventType: '50m',
        value: 7.41,
        unit: '秒',
        measuredAt: day2,
      ),
      _rec(
        id: 'r2',
        athleteId: 'a1',
        athleteName: 'たろう',
        eventId: 'e50',
        eventType: '50m',
        value: 7.21,
        unit: '秒',
        measuredAt: day1,
      ),
    ];

    final sessions = buildDailySessions(records, events);
    final newer = sessions.first.rows.single; // 6/12 = 7.21
    final older = sessions[1].rows.single; // 5/30 = 7.41
    expect(newer.cells['id:e50']!.isPersonalBest, isTrue);
    expect(older.cells['id:e50']!.isPersonalBest, isFalse);
  });

  test('距離は大きい方が自己ベスト', () {
    final records = [
      _rec(
        id: 'r1',
        athleteId: 'a1',
        athleteName: 'たろう',
        eventId: 'ehj',
        eventType: '立ち幅跳び',
        value: 220,
        unit: 'cm',
        measuredAt: day2,
      ),
      _rec(
        id: 'r2',
        athleteId: 'a1',
        athleteName: 'たろう',
        eventId: 'ehj',
        eventType: '立ち幅跳び',
        value: 230,
        unit: 'cm',
        measuredAt: day1,
      ),
    ];

    final sessions = buildDailySessions(records, events);
    final newer = sessions.first.rows.single; // 6/12 = 230
    final older = sessions[1].rows.single; // 5/30 = 220
    expect(newer.cells['id:ehj']!.isPersonalBest, isTrue);
    expect(older.cells['id:ehj']!.isPersonalBest, isFalse);
  });

  test('種目マスタに存在しない距離記録も大きい方を自己ベストにする', () {
    final records = [
      _rec(
        id: 'r1',
        athleteId: 'a1',
        athleteName: 'たろう',
        eventId: 'deleted-distance-event',
        eventType: '削除済み距離種目',
        value: 220,
        unit: 'cm',
        measuredAt: day2,
      ),
      _rec(
        id: 'r2',
        athleteId: 'a1',
        athleteName: 'たろう',
        eventId: 'deleted-distance-event',
        eventType: '削除済み距離種目',
        value: 230,
        unit: 'cm',
        measuredAt: day1,
      ),
    ];

    final sessions = buildDailySessions(records, const []);
    final newer = sessions.first.rows.single; // 6/12 = 230
    final older = sessions[1].rows.single; // 5/30 = 220
    expect(newer.cells['id:deleted-distance-event']!.isPersonalBest, isTrue);
    expect(older.cells['id:deleted-distance-event']!.isPersonalBest, isFalse);
    expect(sessions.first.columns.single.recordType, EventRecordType.distance);
  });

  test('日別集計は削除済み種目のrecordTypeを使う（m単位でも距離扱い）', () async {
    // 単位 'm' は単位推測だと time(小さい方が良い)に倒れてしまうが、
    // 削除済み種目の recordType=distance を参照して大きい方を自己ベストにする。
    final deletedDistance = _event(
      id: 'ehj-old',
      name: '走り幅跳び(旧)',
      type: EventRecordType.distance,
      sortOrder: 5,
    ).copyWith(deletedAt: DateTime(2026, 6, 1));

    final records = [
      _rec(
        id: 'r1',
        athleteId: 'a1',
        athleteName: 'たろう',
        eventId: 'ehj-old',
        eventType: '走り幅跳び(旧)',
        value: 4.5,
        unit: 'm',
        measuredAt: day2,
      ),
      _rec(
        id: 'r2',
        athleteId: 'a1',
        athleteName: 'たろう',
        eventId: 'ehj-old',
        eventType: '走り幅跳び(旧)',
        value: 5.0,
        unit: 'm',
        measuredAt: day1,
      ),
    ];

    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue('u1'),
        recordRepositoryProvider.overrideWithValue(
          _FakeRecordRepository(records),
        ),
        eventRepositoryProvider.overrideWithValue(
          _FakeEventRepository([deletedDistance]),
        ),
      ],
    );
    addTearDown(container.dispose);

    final state = await _waitForDailyLoaded(container);
    final sessions = state.maybeWhen(
      loaded: (sessions, _) => sessions,
      orElse: () => <DailySession>[],
    );

    expect(sessions.first.columns.single.recordType, EventRecordType.distance);
    // 距離は大きい方がベスト → 5.0(新しい日)がPB、4.5(古い日)は非PB
    expect(
      sessions.first.rows.single.cells['id:ehj-old']!.isPersonalBest,
      true,
    );
    expect(sessions[1].rows.single.cells['id:ehj-old']!.isPersonalBest, false);
  });

  test('記録保存後に一覧だけ更新されると日別ビューも新しい記録を反映する', () async {
    final records = [
      _rec(
        id: 'r1',
        athleteId: 'a1',
        athleteName: 'たろう',
        eventId: 'e50',
        eventType: '50m',
        value: 7.50,
        unit: '秒',
        measuredAt: day1,
      ),
    ];
    final recordRepository = _FakeRecordRepository(records);
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue('u1'),
        recordRepositoryProvider.overrideWithValue(recordRepository),
        eventRepositoryProvider.overrideWithValue(_FakeEventRepository(events)),
      ],
    );
    addTearDown(container.dispose);

    final initialState = await _waitForDailyLoaded(container);
    expect(
      initialState.when(
        loading: () => null,
        error: (_) => null,
        loaded: (sessions, _) =>
            sessions.single.rows.single.cells['id:e50']!.value,
      ),
      7.50,
    );

    await recordRepository.saveRecord(
      _rec(
        id: 'r2',
        athleteId: 'a1',
        athleteName: 'たろう',
        eventId: 'e50',
        eventType: '50m',
        value: 7.20,
        unit: '秒',
        measuredAt: day1,
      ),
    );
    container.invalidate(recordListNotifierProvider);
    final updatedListState = await _waitForRecordListLoaded(container);
    expect(
      updatedListState.when(
        loading: () => null,
        error: (_) => null,
        loaded: (records, _, _) => records
            .firstWhere((record) => record.id == 'r2')
            .effectiveRecordValue,
      ),
      7.20,
    );

    final updatedState = container.read(dailyRecordsNotifierProvider);
    expect(
      updatedState.when(
        loading: () => null,
        error: (_) => null,
        loaded: (sessions, _) =>
            sessions.single.rows.single.cells['id:e50']!.value,
      ),
      7.20,
    );
  });

  test('日別ビューも記録フィルターの選手条件を反映する', () async {
    final records = [
      _rec(
        id: 'r1',
        athleteId: 'a1',
        athleteName: 'たろう',
        eventId: 'e50',
        eventType: '50m',
        value: 7.21,
        unit: '秒',
        measuredAt: day1,
      ),
      _rec(
        id: 'r2',
        athleteId: 'a2',
        athleteName: 'じろう',
        eventId: 'e50',
        eventType: '50m',
        value: 7.35,
        unit: '秒',
        measuredAt: day1,
      ),
    ];
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue('u1'),
        recordRepositoryProvider.overrideWithValue(
          _FakeRecordRepository(records),
        ),
        eventRepositoryProvider.overrideWithValue(_FakeEventRepository(events)),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(recordFilterNotifierProvider.notifier)
        .setAthlete(athleteId: 'a1', athleteName: 'たろう');

    final state = await _waitForDailyLoaded(container);
    final rows = state.when(
      loading: () => const <DailyAthleteRow>[],
      error: (_) => const <DailyAthleteRow>[],
      loaded: (sessions, _) => sessions.single.rows,
    );

    expect(rows.map((row) => row.name), ['たろう']);
  });
}
