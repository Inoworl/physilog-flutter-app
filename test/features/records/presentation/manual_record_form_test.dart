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
  Future<List<MeasurementRecord>> getAllRecords({
    required String userId,
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
  Future<List<Event>> getEvents({
    required String userId,
    bool includeDeleted = false,
  }) async {
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

Event _event({
  required EventRecordType recordType,
  required String unit,
  String name = '種目',
}) {
  return Event(
    id: 'event-1',
    userId: 'test-user-id',
    name: name,
    unit: unit,
    recordType: recordType,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

Future<void> _openForm(
  WidgetTester tester, {
  required _FakeRecordRepository records,
  required Event event,
}) async {
  final athletes = _FakeAthleteRepository([
    Athlete(
      id: 'athlete-1',
      userId: 'test-user-id',
      name: '山田太郎',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
  ]);
  final events = _FakeEventRepository([event]);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        recordRepositoryProvider.overrideWithValue(records),
        athleteRepositoryProvider.overrideWithValue(athletes),
        eventRepositoryProvider.overrideWithValue(events),
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
}

void main() {
  testWidgets('キーパッドで入力した値を種目の単位で保存する', (tester) async {
    final records = _FakeRecordRepository();
    await _openForm(
      tester,
      records: records,
      event: _event(recordType: EventRecordType.count, unit: '回', name: '腕立て'),
    );

    final list = find.byType(ListView).last;
    await tester.dragUntilVisible(
      find.widgetWithText(OutlinedButton, '1'),
      list,
      const Offset(0, -200),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, '1'));
    await tester.pump();
    await tester.tap(find.widgetWithText(OutlinedButton, '5'));
    await tester.pump();

    final submit = find.widgetWithText(FilledButton, '記録する');
    await tester.dragUntilVisible(submit, list, const Offset(0, -200));
    await tester.tap(submit, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(records.savedRecords, hasLength(1));
    final saved = records.savedRecords.single;
    expect(saved.athleteName, '山田太郎');
    expect(saved.eventType, '腕立て');
    expect(saved.recordValue, 15);
    expect(saved.recordUnit, '回');
    expect(saved.formattedRecordValue, '15回');
    expect(saved.durationMs, 0);
  });

  testWidgets('記録値を入れずに保存しても記録は作られない', (tester) async {
    final records = _FakeRecordRepository();
    await _openForm(
      tester,
      records: records,
      event: _event(recordType: EventRecordType.distance, unit: 'cm'),
    );

    final list = find.byType(ListView).last;
    final submit = find.widgetWithText(FilledButton, '記録する');
    await tester.dragUntilVisible(submit, list, const Offset(0, -200));
    await tester.tap(submit, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(records.savedRecords, isEmpty);
  });
}
