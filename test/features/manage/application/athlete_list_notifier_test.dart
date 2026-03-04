import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:physi_log/features/manage/application/athlete_list_notifier.dart';
import 'package:physi_log/features/manage/data/local_athlete_repository.dart';
import 'package:physi_log/features/records/data/local_record_repository.dart';
import 'package:physi_log/models/athlete.dart';
import 'package:physi_log/models/measurement_record.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('physilog_athletes_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    if (Hive.isBoxOpen('athletes')) {
      final box = Hive.box<Map>('athletes');
      await box.clear();
      await box.close();
    }
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

  test('選手を追加すると一覧に反映される', () async {
    final athleteRepository = LocalAthleteRepository();
    final recordRepository = LocalRecordRepository();
    final notifier = AthleteListNotifier(
      repository: athleteRepository,
      recordRepository: recordRepository,
      userId: 'local-user',
    );

    await notifier.addAthlete('太郎');

    final loaded = notifier.state.maybeWhen(
      loaded: (athletes) => athletes,
      orElse: () => null,
    );

    expect(loaded, isNotNull);
    expect(loaded!.length, 1);
    expect(loaded.single.name, '太郎');
    expect(loaded.single.userId, 'local-user');
  });

  test('既存記録から選手一覧を自動補完しathleteIdを補完する', () async {
    final athleteRepository = LocalAthleteRepository();
    final recordRepository = LocalRecordRepository();
    final now = DateTime.now();

    await recordRepository.saveRecord(
      MeasurementRecord(
        id: 'record-1',
        userId: 'local-user',
        athleteName: '花子',
        eventType: '50m走',
        startMs: 1000,
        endMs: 2300,
        durationMs: 1300,
        measuredAt: now,
        memo: '',
        createdAt: now,
        updatedAt: now,
      ),
    );

    final notifier = AthleteListNotifier(
      repository: athleteRepository,
      recordRepository: recordRepository,
      userId: 'local-user',
    );
    await notifier.refresh();

    final athletes = notifier.state.maybeWhen(
      loaded: (athletes) => athletes,
      orElse: () => <Athlete>[],
    );
    expect(athletes, hasLength(1));
    expect(athletes.single.name, '花子');

    final records = await recordRepository.getRecords(userId: 'local-user');
    expect(records, hasLength(1));
    expect(records.single.athleteId, isNotNull);
    expect(records.single.athleteId, athletes.single.id);
  });
}
