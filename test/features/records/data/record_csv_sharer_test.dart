import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/billing/domain/recording_scope.dart';
import 'package:physi_log/features/records/data/record_csv_sharer.dart';
import 'package:physi_log/features/records/domain/record_csv.dart';

import '../../billing/support/plan_fixture.dart';

void main() {
  test(
    'Sharing writes only an explicitly authorized CSV in temporary application storage',
    () async {
      final directory = await Directory.systemTemp.createTemp('csv-test-');
      addTearDown(() => directory.delete(recursive: true));
      var checks = 0;
      String? exported;
      final sharer = RecordCsvSharer(
        temporaryDirectory: () async => directory,
        launch: (filePath, origin) async {
          exported = filePath;
          expect(origin.width, 100);
          expect(
            utf8.decode(await File(filePath).readAsBytes()),
            contains('選手 1'),
          );
        },
      );
      await sharer.share(
        RecordCsv.encode([fixtureRecord()]),
        origin: const Rect.fromLTWH(0, 0, 100, 40),
        authorize: () {
          checks++;
        },
      );
      expect(checks, 3);
      expect(exported, endsWith('/physilog-records.csv'));
      expect(exported, isNot(contains('fixture-owner')));
      expect(File(exported!).existsSync(), isTrue);
    },
  );

  test(
    'Revocation during file preparation deletes the file and never opens sharing',
    () async {
      final directory = await Directory.systemTemp.createTemp('csv-test-');
      addTearDown(() => directory.delete(recursive: true));
      var checks = 0;
      var launched = false;
      final sharer = RecordCsvSharer(
        temporaryDirectory: () async => directory,
        launch: (filePath, origin) async {
          launched = true;
        },
      );
      await expectLater(
        sharer.share(
          RecordCsv.encode([fixtureRecord()]),
          origin: const Rect.fromLTWH(0, 0, 100, 40),
          authorize: () {
            if (++checks == 3) throw const PlanAccessException('expired');
          },
        ),
        throwsA(isA<PlanAccessException>()),
      );
      expect(launched, isFalse);
      expect(
        await directory
            .list(recursive: true)
            .where((entity) => entity is File)
            .toList(),
        isEmpty,
      );
    },
  );
}
