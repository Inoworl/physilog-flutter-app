import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/models/measurement_record.dart';

void main() {
  test('手動記録の値と単位を優先して表示できる', () {
    final record = MeasurementRecord(
      id: 'record-1',
      userId: 'user-1',
      athleteName: '山田太郎',
      eventType: '腕立て伏せ',
      startMs: 0,
      endMs: 0,
      durationMs: 0,
      measuredAt: DateTime(2026, 4, 20),
      recordValue: 15,
      recordUnit: '回',
      createdAt: DateTime(2026, 4, 20),
      updatedAt: DateTime(2026, 4, 20),
    );

    expect(record.formattedRecordValue, '15回');
    expect(record.recordValueInputText, '15回');
    expect(record.accuracyInfo, isNull);
  });

  test('手動記録の単位がない値も文字列として表示できる', () {
    final record = MeasurementRecord(
      id: 'record-1',
      userId: 'user-1',
      athleteName: '山田太郎',
      eventType: '腕立て伏せ',
      startMs: 0,
      endMs: 0,
      durationMs: 0,
      measuredAt: DateTime(2026, 4, 20),
      recordValue: 15,
      createdAt: DateTime(2026, 4, 20),
      updatedAt: DateTime(2026, 4, 20),
    );

    expect(record.formattedRecordValue, '15');
    expect(record.recordValueInputText, '15');
  });

  test('秒単位の手動記録は分秒の文字列として表示できる', () {
    final record = MeasurementRecord(
      id: 'record-1',
      userId: 'user-1',
      athleteName: '山田太郎',
      eventType: '1500m',
      startMs: 0,
      endMs: 0,
      durationMs: 0,
      measuredAt: DateTime(2026, 4, 20),
      recordValue: 62,
      recordUnit: '秒',
      createdAt: DateTime(2026, 4, 20),
      updatedAt: DateTime(2026, 4, 20),
    );

    expect(record.formattedRecordValue, '1分02秒');
    expect(record.recordValueInputText, '1分02秒');
  });

  test('秒単位の手動記録は時間分秒の文字列として表示できる', () {
    final record = MeasurementRecord(
      id: 'record-1',
      userId: 'user-1',
      athleteName: '山田太郎',
      eventType: 'マラソン',
      startMs: 0,
      endMs: 0,
      durationMs: 0,
      measuredAt: DateTime(2026, 4, 20),
      recordValue: 3723,
      recordUnit: '秒',
      createdAt: DateTime(2026, 4, 20),
      updatedAt: DateTime(2026, 4, 20),
    );

    expect(record.formattedRecordValue, '1時間02分03秒');
    expect(record.recordValueInputText, '1時間02分03秒');
  });
}
