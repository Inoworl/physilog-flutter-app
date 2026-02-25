import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:physi_log/features/records/application/record_list_notifier.dart';
import 'package:physi_log/features/records/domain/record_filter.dart';
import 'package:physi_log/features/records/domain/record_repository.dart';
import 'package:physi_log/features/records/presentation/manual_record_form.dart';
import 'package:physi_log/models/measurement_record.dart';
import 'package:physi_log/providers/app_providers.dart';

class _FakeRecordRepository implements RecordRepository {
  final List<MeasurementRecord> savedRecords = [];

  @override
  Future<void> deleteRecord(String id) async {
    savedRecords.removeWhere((record) => record.id == id);
  }

  @override
  Future<MeasurementRecord?> getRecord(String id) async {
    try {
      return savedRecords.firstWhere((record) => record.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<MeasurementRecord>> getRecords({
    required String userId,
    RecordFilter? filter,
    int limit = 20,
    MeasurementRecord? lastRecord,
  }) async {
    return savedRecords.where((record) => record.userId == userId).toList();
  }

  @override
  Future<void> saveRecord(MeasurementRecord record) async {
    savedRecords.add(record);
  }

  @override
  Future<void> updateRecord(MeasurementRecord record) async {
    final index = savedRecords.indexWhere((item) => item.id == record.id);
    if (index >= 0) {
      savedRecords[index] = record;
    }
  }
}

void main() {
  testWidgets('手動記録フォーム送信で記録が保存される', (tester) async {
    final fakeRepository = _FakeRecordRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recordRepositoryProvider.overrideWithValue(fakeRepository),
          currentUserIdProvider.overrideWithValue('test-user-id'),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => ManualRecordForm.show(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, '選手名'), '山田太郎');
    await tester.enterText(find.widgetWithText(TextFormField, '種目'), '50m走');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'タイム（秒）'),
      '12.34',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'メモ'), 'テストメモ');

    final submitButton = find.widgetWithText(FilledButton, '記録する');
    await tester.dragUntilVisible(
      submitButton,
      find.byType(ListView).last,
      const Offset(0, -200),
    );
    await tester.tap(submitButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(fakeRepository.savedRecords.length, 1);
    final saved = fakeRepository.savedRecords.single;
    expect(saved.userId, 'test-user-id');
    expect(saved.athleteName, '山田太郎');
    expect(saved.eventType, '50m走');
    expect(saved.durationMs, 12340);
    expect(saved.startMs, 0);
    expect(saved.endMs, 12340);
    expect(saved.memo, 'テストメモ');
  });
}
