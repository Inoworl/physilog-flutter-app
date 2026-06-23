import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/records/application/daily_records_notifier.dart';
import 'package:physi_log/models/event.dart';
import 'package:physi_log/models/measurement_record.dart';

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
}
