import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:physi_log/features/manage/application/athlete_list_notifier.dart';
import 'package:physi_log/features/manage/data/local_athlete_repository.dart';

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
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('選手を追加すると一覧に反映される', () async {
    final repository = LocalAthleteRepository();
    final notifier = AthleteListNotifier(
      repository: repository,
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
}
