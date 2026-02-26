import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:physi_log/features/measurement/application/measurement_notifier.dart';
import 'package:physi_log/features/records/data/local_record_repository.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('physilog_test_');
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

  test('saveRecordで保存した記録がリポジトリから取得できる', () async {
    final repository = LocalRecordRepository();
    final notifier = MeasurementNotifier(
      repository: repository,
      userId: 'local-user',
    );
    notifier.setStartPosition(const Duration(seconds: 1));
    notifier.setEndPosition(const Duration(seconds: 2));
    notifier.setAthleteName('テスト選手');
    notifier.setEventType('30m走');

    final result = await notifier.saveRecord(videoPath: '/tmp/test.mp4');
    expect(result, isNotNull);

    final saved = await repository.getRecords(userId: 'local-user');

    expect(saved.length, 1);
    expect(saved.single.userId, 'local-user');
    expect(saved.single.athleteName, 'テスト選手');
  });

  test('saveRecord成功時にonRecordSavedが呼ばれる', () async {
    final repository = LocalRecordRepository();
    var callbackCount = 0;
    final notifier = MeasurementNotifier(
      repository: repository,
      userId: 'local-user',
      onRecordSaved: () {
        callbackCount++;
      },
    );
    notifier.setStartPosition(const Duration(milliseconds: 500));
    notifier.setEndPosition(const Duration(milliseconds: 1500));
    notifier.setAthleteName('テスト選手');
    notifier.setEventType('50m走');

    final result = await notifier.saveRecord(videoPath: '/tmp/test.mp4');

    expect(result, isNotNull);
    expect(callbackCount, 1);
  });
}
