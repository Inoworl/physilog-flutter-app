import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/records/application/athlete_sheet.dart';
import 'package:physi_log/models/event.dart';
import 'package:physi_log/models/measurement_record.dart';

Event _event({
  required String id,
  required String name,
  EventRecordType recordType = EventRecordType.time,
  int sortOrder = 0,
}) {
  return Event(
    id: id,
    userId: 'u1',
    name: name,
    unit: recordType.defaultUnit,
    recordType: recordType,
    sortOrder: sortOrder,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

MeasurementRecord _record({
  required String id,
  required String eventId,
  required String eventType,
  required double value,
  required String unit,
  required DateTime measuredAt,
}) {
  return MeasurementRecord(
    id: id,
    userId: 'u1',
    athleteId: 'a1',
    eventId: eventId,
    athleteName: 'たろう',
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

void main() {
  final events = [
    _event(
      id: 'e1',
      name: '30m走',
      recordType: EventRecordType.time,
      sortOrder: 0,
    ),
    _event(
      id: 'e2',
      name: '立ち幅跳び',
      recordType: EventRecordType.distance,
      sortOrder: 1,
    ),
  ];

  test('行は計測日（新しい順）、列はsortOrder順に並ぶ', () {
    final sheet = buildAthleteSheet(
      records: [
        _record(
          id: 'r1',
          eventId: 'e1',
          eventType: '30m走',
          value: 4.6,
          unit: '秒',
          measuredAt: DateTime(2026, 6, 1, 10),
        ),
        _record(
          id: 'r2',
          eventId: 'e2',
          eventType: '立ち幅跳び',
          value: 230,
          unit: 'cm',
          measuredAt: DateTime(2026, 6, 12, 10),
        ),
      ],
      events: events,
    );

    expect(sheet.columns.map((c) => c.name).toList(), ['30m走', '立ち幅跳び']);
    expect(sheet.rows.length, 2);
    // 新しい順：6/12 が先頭。
    expect(sheet.rows.first.date, DateTime(2026, 6, 12));
    expect(sheet.rows.last.date, DateTime(2026, 6, 1));
  });

  test('同じ日・同じ種目はベストに集約（タイムは速い方）', () {
    final sheet = buildAthleteSheet(
      records: [
        _record(
          id: 'r1',
          eventId: 'e1',
          eventType: '30m走',
          value: 4.6,
          unit: '秒',
          measuredAt: DateTime(2026, 6, 1, 10),
        ),
        _record(
          id: 'r2',
          eventId: 'e1',
          eventType: '30m走',
          value: 4.4,
          unit: '秒',
          measuredAt: DateTime(2026, 6, 1, 11),
        ),
      ],
      events: events,
    );

    expect(sheet.rows.length, 1);
    final cell = sheet.rows.first.cells['e1']!;
    expect(cell.value, 4.4);
    expect(cell.recordId, 'r2');
    expect(cell.displayText, '4.4秒');
  });

  test('未計測の種目セルは欠損する', () {
    final sheet = buildAthleteSheet(
      records: [
        _record(
          id: 'r1',
          eventId: 'e1',
          eventType: '30m走',
          value: 4.6,
          unit: '秒',
          measuredAt: DateTime(2026, 6, 1, 10),
        ),
      ],
      events: events,
    );

    final row = sheet.rows.single;
    expect(row.cells.containsKey('e1'), isTrue);
    expect(row.cells.containsKey('e2'), isFalse);
  });

  test('記録が無ければ空シート', () {
    final sheet = buildAthleteSheet(records: const [], events: events);
    expect(sheet.isEmpty, isTrue);
  });
}
