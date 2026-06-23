import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/manage/domain/athlete_repository.dart';
import 'package:physi_log/features/manage/domain/event_repository.dart';
import 'package:physi_log/features/manage/presentation/athlete_form_sheet.dart';
import 'package:physi_log/features/records/domain/record_filter.dart';
import 'package:physi_log/features/records/domain/record_repository.dart';
import 'package:physi_log/models/athlete.dart';
import 'package:physi_log/models/event.dart';
import 'package:physi_log/models/measurement_record.dart';
import 'package:physi_log/providers/app_providers.dart';

class _FakeAthleteRepository implements AthleteRepository {
  final List<Athlete> athletes = [];

  @override
  Future<void> deleteAthlete({
    required String userId,
    required String id,
  }) async {
    athletes.removeWhere((athlete) => athlete.id == id);
  }

  @override
  Future<List<Athlete>> getAthletes({required String userId}) async {
    return athletes.where((athlete) => athlete.userId == userId).toList();
  }

  @override
  Future<void> saveAthlete(Athlete athlete) async {
    athletes.add(athlete);
  }

  @override
  Future<void> updateAthlete(Athlete athlete) async {
    final index = athletes.indexWhere((item) => item.id == athlete.id);
    if (index >= 0) {
      athletes[index] = athlete;
    }
  }
}

class _FakeEventRepository implements EventRepository {
  @override
  Future<void> deleteEvent({
    required String userId,
    required String id,
  }) async {}

  @override
  Future<List<Event>> getEvents({required String userId}) async => [];

  @override
  Future<void> saveEvent(Event event) async {}

  @override
  Future<void> updateEvent(Event event) async {}
}

class _FakeRecordRepository implements RecordRepository {
  @override
  Future<void> deleteRecord({
    required String userId,
    required String id,
  }) async {}

  @override
  Future<MeasurementRecord?> getRecord({
    required String userId,
    required String id,
  }) async {
    return null;
  }

  @override
  Future<List<MeasurementRecord>> getRecords({
    required String userId,
    RecordFilter? filter,
    int limit = 20,
    MeasurementRecord? lastRecord,
  }) async {
    return [];
  }

  @override
  Future<List<MeasurementRecord>> getAllRecords({
    required String userId,
  }) async {
    return [];
  }

  @override
  Future<void> saveRecord(MeasurementRecord record) async {}

  @override
  Future<void> updateRecord(MeasurementRecord record) async {}
}

void main() {
  testWidgets('選手登録フォームは入力した年齢を保存する', (tester) async {
    final athleteRepository = _FakeAthleteRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('test-user'),
          athleteRepositoryProvider.overrideWithValue(athleteRepository),
          eventRepositoryProvider.overrideWithValue(_FakeEventRepository()),
          recordRepositoryProvider.overrideWithValue(_FakeRecordRepository()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => AthleteFormSheet.show(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, '選手名'), '山田太郎');
    await tester.enterText(find.widgetWithText(TextFormField, '年齢（任意）'), '12');
    await tester.tap(find.widgetWithText(FilledButton, '登録する'));
    await tester.pumpAndSettle();

    expect(athleteRepository.athletes, hasLength(1));
    expect(athleteRepository.athletes.single.name, '山田太郎');
    expect(athleteRepository.athletes.single.age, 12);
  });
}
