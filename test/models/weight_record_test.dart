import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/models/event.dart';
import 'package:physi_log/models/measurement_record.dart';
import 'package:physi_log/models/record_set.dart';

void main() {
  test('EventRecordType.weight は kg・大きいほど良い・手入力', () {
    expect(EventRecordType.weight.defaultUnit, 'kg');
    expect(EventRecordType.weight.lowerIsBetter, isFalse);
    expect(
      EventRecordType.weight.defaultMeasurementMethod,
      EventMeasurementMethod.manual,
    );
  });

  test('weight種目のベスト方向は higher（大きいほど良い）', () {
    final now = DateTime(2026, 7, 1);
    final event = Event(
      id: 'e1',
      userId: 'u1',
      name: 'ベンチプレス',
      unit: 'kg',
      recordType: EventRecordType.weight,
      createdAt: now,
      updatedAt: now,
    );
    expect(event.effectiveScoreDirection, EventScoreDirection.higher);
    expect(event.scoreLowerIsBetter, isFalse);
  });

  test('RecordSet.formatted は 60kg×10 の形（小数は残す）', () {
    expect(const RecordSet(weight: 60, reps: 10).formatted, '60kg×10');
    expect(const RecordSet(weight: 62.5, reps: 8).formatted, '62.5kg×8');
  });

  test('sets付き記録は toFirestore に sets を含み、setCount/formattedSetsが効く', () {
    final now = DateTime(2026, 7, 1, 10);
    final record = MeasurementRecord(
      id: 'r1',
      userId: 'u1',
      athleteId: 'a1',
      eventId: 'e1',
      athleteName: '山田',
      eventType: 'ベンチプレス',
      startMs: 0,
      endMs: 0,
      durationMs: 0,
      recordValue: 80,
      recordUnit: 'kg',
      measuredAt: now,
      sets: const [
        RecordSet(weight: 60, reps: 10),
        RecordSet(weight: 70, reps: 8),
        RecordSet(weight: 80, reps: 5),
      ],
      createdAt: now,
      updatedAt: now,
    );

    final data = record.toFirestore();
    expect(data['value'], 80); // 代表値＝最大重量
    expect(data['unit'], 'kg');
    expect(data['sets'], [
      {'weight': 60.0, 'reps': 10},
      {'weight': 70.0, 'reps': 8},
      {'weight': 80.0, 'reps': 5},
    ]);

    expect(record.hasSets, isTrue);
    expect(record.setCount, 3);
    expect(record.formattedSets, '60kg×10 / 70kg×8 / 80kg×5');
  });

  test('sets無しの記録は toFirestore に sets を含めない', () {
    final now = DateTime(2026, 7, 1, 10);
    final record = MeasurementRecord(
      id: 'r1',
      userId: 'u1',
      athleteName: '山田',
      eventType: '100m',
      startMs: 0,
      endMs: 0,
      durationMs: 0,
      recordValue: 12.3,
      recordUnit: '秒',
      measuredAt: now,
      createdAt: now,
      updatedAt: now,
    );
    final data = record.toFirestore();
    expect(data.containsKey('sets'), isFalse);
    expect(record.hasSets, isFalse);
  });
}
