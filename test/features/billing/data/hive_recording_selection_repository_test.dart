import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:physi_log/features/billing/data/hive_recording_selection_repository.dart';
import 'package:physi_log/features/billing/domain/recording_scope.dart';

void main() {
  test(
    'Selections survive reopening but never leak between owners or data stores',
    () async {
      final directory = await Directory.systemTemp.createTemp('scope-test-');
      Hive.init(directory.path);
      addTearDown(() async {
        await Hive.close();
        await directory.delete(recursive: true);
      });
      final repository = HiveRecordingSelectionRepository();
      await repository.write(
        'firestore:first',
        const RecordingSelection(athleteIds: {'chosen'}, eventIds: {'event'}),
      );
      await Hive.close();
      expect((await repository.read('firestore:first')).athleteIds, {'chosen'});
      expect((await repository.read('firestore:second')).athleteIds, isEmpty);
      expect((await repository.read('local:first')).athleteIds, isEmpty);
    },
  );
}
