import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:physi_log/features/records/data/local_record_repository.dart';
import 'package:physi_log/models/measurement_record.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('physilog_records_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    if (Hive.isBoxOpen('records')) {
      final box = Hive.box<Map>('records');
      await box.clear();
      await box.close();
    }
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('記録を作成・取得・一覧表示・更新・削除できる', () async {
    final repository = LocalRecordRepository();
    final now = DateTime(2026, 5, 23, 10);
    final record = MeasurementRecord(
      id: 'record-1',
      userId: 'local-user',
      athleteId: 'athlete-1',
      eventId: 'event-1',
      athleteName: '山田太郎',
      eventType: '50m走',
      startMs: 0,
      endMs: 12340,
      durationMs: 12340,
      recordValue: 12.34,
      recordUnit: '秒',
      measuredAt: now,
      memo: '初回',
      createdAt: now,
      updatedAt: now,
    );

    await repository.saveRecord(record);

    final created = await repository.getRecord(
      userId: 'local-user',
      id: record.id,
    );
    expect(created, record);

    final records = await repository.getRecords(userId: 'local-user');
    expect(records, [record]);

    final updated = record.copyWith(
      recordValue: 12.12,
      durationMs: 12120,
      endMs: 12120,
      memo: '更新',
      updatedAt: now.add(const Duration(minutes: 1)),
    );
    await repository.updateRecord(updated);

    final afterUpdate = await repository.getRecord(
      userId: 'local-user',
      id: record.id,
    );
    expect(afterUpdate?.recordValue, 12.12);
    expect(afterUpdate?.memo, '更新');

    await repository.deleteRecord(userId: 'local-user', id: record.id);

    expect(
      await repository.getRecord(userId: 'local-user', id: record.id),
      isNull,
    );
    expect(await repository.getRecords(userId: 'local-user'), isEmpty);
  });
}
