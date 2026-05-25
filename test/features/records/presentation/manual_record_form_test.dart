import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:physi_log/features/manage/domain/athlete_repository.dart';
import 'package:physi_log/features/manage/domain/event_repository.dart';
import 'package:physi_log/models/athlete.dart';
import 'package:physi_log/models/event.dart';
import 'package:physi_log/features/records/domain/record_filter.dart';
import 'package:physi_log/features/records/domain/record_repository.dart';
import 'package:physi_log/features/records/presentation/manual_record_form.dart';
import 'package:physi_log/models/measurement_record.dart';
import 'package:physi_log/providers/app_providers.dart';

class _FakeRecordRepository implements RecordRepository {
  final List<MeasurementRecord> savedRecords = [];

  @override
  Future<void> deleteRecord({
    required String userId,
    required String id,
  }) async {
    savedRecords.removeWhere((record) => record.id == id);
  }

  @override
  Future<MeasurementRecord?> getRecord({
    required String userId,
    required String id,
  }) async {
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

class _FakeAthleteRepository implements AthleteRepository {
  _FakeAthleteRepository(this._athletes);

  final List<Athlete> _athletes;

  @override
  Future<void> deleteAthlete({
    required String userId,
    required String id,
  }) async {
    _athletes.removeWhere((athlete) => athlete.id == id);
  }

  @override
  Future<List<Athlete>> getAthletes({required String userId}) async {
    return _athletes.where((athlete) => athlete.userId == userId).toList();
  }

  @override
  Future<void> saveAthlete(Athlete athlete) async {
    _athletes.add(athlete);
  }

  @override
  Future<void> updateAthlete(Athlete athlete) async {
    final index = _athletes.indexWhere((item) => item.id == athlete.id);
    if (index >= 0) {
      _athletes[index] = athlete;
    }
  }
}

class _FakeEventRepository implements EventRepository {
  _FakeEventRepository(this._events);

  final List<Event> _events;

  @override
  Future<void> deleteEvent({required String userId, required String id}) async {
    _events.removeWhere((event) => event.id == id);
  }

  @override
  Future<List<Event>> getEvents({required String userId}) async {
    return _events.where((event) => event.userId == userId).toList();
  }

  @override
  Future<void> saveEvent(Event event) async {
    _events.add(event);
  }

  @override
  Future<void> updateEvent(Event event) async {
    final index = _events.indexWhere((item) => item.id == event.id);
    if (index >= 0) {
      _events[index] = event;
    }
  }
}

void main() {
  testWidgets('手動記録フォーム送信で記録値入力から値と単位を分解して保存する', (tester) async {
    final fakeRepository = _FakeRecordRepository();
    final fakeAthleteRepository = _FakeAthleteRepository([
      Athlete(
        id: 'athlete-1',
        userId: 'test-user-id',
        name: '山田太郎',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    ]);
    final fakeEventRepository = _FakeEventRepository([
      Event(
        id: 'event-1',
        userId: 'test-user-id',
        name: '50m走',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recordRepositoryProvider.overrideWithValue(fakeRepository),
          athleteRepositoryProvider.overrideWithValue(fakeAthleteRepository),
          eventRepositoryProvider.overrideWithValue(fakeEventRepository),
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

    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(DropdownButtonFormField<String>).evaluate().isNotEmpty) {
        break;
      }
    }
    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(2));

    expect(find.widgetWithText(TextFormField, '単位'), findsNothing);

    await tester.enterText(find.widgetWithText(TextFormField, '記録値'), '１５回');
    await tester.drag(find.byType(ListView).last, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'メモ'), 'テストメモ');

    final formList = find.byType(ListView).last;
    for (var i = 0; i < 8; i++) {
      await tester.drag(formList, const Offset(0, -300));
      await tester.pumpAndSettle();
    }

    final submitButton = find.widgetWithText(FilledButton, '記録する');
    expect(submitButton, findsOneWidget);
    await tester.tap(submitButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(fakeRepository.savedRecords.length, 1);
    final saved = fakeRepository.savedRecords.single;
    expect(saved.userId, 'test-user-id');
    expect(saved.athleteId, 'athlete-1');
    expect(saved.athleteName, '山田太郎');
    expect(saved.eventType, '50m走');
    expect(saved.recordValue, 15);
    expect(saved.recordUnit, '回');
    expect(saved.formattedRecordValue, '15回');
    expect(saved.durationMs, 0);
    expect(saved.startMs, 0);
    expect(saved.endMs, 0);
    expect(saved.memo, 'テストメモ');
  });

  testWidgets('手動記録フォームは数値を含まない記録値を保存しない', (tester) async {
    final fakeRepository = _FakeRecordRepository();
    final fakeAthleteRepository = _FakeAthleteRepository([
      Athlete(
        id: 'athlete-1',
        userId: 'test-user-id',
        name: '山田太郎',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    ]);
    final fakeEventRepository = _FakeEventRepository([
      Event(
        id: 'event-1',
        userId: 'test-user-id',
        name: '50m走',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recordRepositoryProvider.overrideWithValue(fakeRepository),
          athleteRepositoryProvider.overrideWithValue(fakeAthleteRepository),
          eventRepositoryProvider.overrideWithValue(fakeEventRepository),
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

    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(DropdownButtonFormField<String>).evaluate().isNotEmpty) {
        break;
      }
    }

    await tester.enterText(find.widgetWithText(TextFormField, '記録値'), '棄権');

    final formList = find.byType(ListView).last;
    for (var i = 0; i < 8; i++) {
      await tester.drag(formList, const Offset(0, -300));
      await tester.pumpAndSettle();
    }

    await tester.tap(
      find.widgetWithText(FilledButton, '記録する'),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(fakeRepository.savedRecords, isEmpty);
  });

  testWidgets('手動記録フォームは単位なしの記録値を保存できる', (tester) async {
    final fakeRepository = _FakeRecordRepository();
    final fakeAthleteRepository = _FakeAthleteRepository([
      Athlete(
        id: 'athlete-1',
        userId: 'test-user-id',
        name: '山田太郎',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    ]);
    final fakeEventRepository = _FakeEventRepository([
      Event(
        id: 'event-1',
        userId: 'test-user-id',
        name: '50m走',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recordRepositoryProvider.overrideWithValue(fakeRepository),
          athleteRepositoryProvider.overrideWithValue(fakeAthleteRepository),
          eventRepositoryProvider.overrideWithValue(fakeEventRepository),
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

    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(DropdownButtonFormField<String>).evaluate().isNotEmpty) {
        break;
      }
    }

    await tester.enterText(find.widgetWithText(TextFormField, '記録値'), '15');

    final formList = find.byType(ListView).last;
    for (var i = 0; i < 8; i++) {
      await tester.drag(formList, const Offset(0, -300));
      await tester.pumpAndSettle();
    }

    await tester.tap(
      find.widgetWithText(FilledButton, '記録する'),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(fakeRepository.savedRecords, hasLength(1));
    final saved = fakeRepository.savedRecords.single;
    expect(saved.recordValue, 15);
    expect(saved.recordUnit, isNull);
    expect(saved.formattedRecordValue, '15');
  });
}
