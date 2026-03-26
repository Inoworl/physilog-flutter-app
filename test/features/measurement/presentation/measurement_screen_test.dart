import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:physi_log/features/manage/application/athlete_list_notifier.dart';
import 'package:physi_log/features/manage/domain/athlete_repository.dart';
import 'package:physi_log/features/measurement/application/measurement_notifier.dart';
import 'package:physi_log/features/measurement/presentation/measurement_screen.dart';
import 'package:physi_log/models/athlete.dart';
import 'package:physi_log/features/records/domain/record_filter.dart';
import 'package:physi_log/features/records/domain/record_repository.dart';
import 'package:physi_log/models/measurement_record.dart';

class _FakeRecordRepository implements RecordRepository {
  @override
  Future<void> deleteRecord(String id) async {}

  @override
  Future<MeasurementRecord?> getRecord(String id) async => null;

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
  Future<void> saveRecord(MeasurementRecord record) async {}

  @override
  Future<void> updateRecord(MeasurementRecord record) async {}
}

class _FakeAthleteRepository implements AthleteRepository {
  @override
  Future<void> deleteAthlete(String id) async {}

  @override
  Future<List<Athlete>> getAthletes({required String userId}) async {
    return [
      Athlete(
        id: 'athlete-1',
        userId: userId,
        name: 'テスト選手',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    ];
  }

  @override
  Future<void> saveAthlete(Athlete athlete) async {}

  @override
  Future<void> updateAthlete(Athlete athlete) async {}
}

void main() {
  testWidgets('続けて測定をタップすると動画取り込み画面へ遷移する', (tester) async {
    final notifier = MeasurementNotifier(
      repository: _FakeRecordRepository(),
      userId: 'local-user',
    )..setStartPosition(const Duration(milliseconds: 500));
    final athleteNotifier = AthleteListNotifier(
      repository: _FakeAthleteRepository(),
      recordRepository: _FakeRecordRepository(),
      userId: 'local-user',
    );

    final router = GoRouter(
      initialLocation: '/measure',
      routes: [
        GoRoute(
          path: '/measure',
          name: 'measurement',
          builder: (_, __) => const MeasurementScreen(),
        ),
        GoRoute(
          path: '/import',
          name: 'videoImport',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('VIDEO_IMPORT_SCREEN'))),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          measurementProvider.overrideWith((ref) => notifier),
          athleteListNotifierProvider.overrideWith((ref) => athleteNotifier),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    final continueButton = find.widgetWithText(OutlinedButton, '続けて測定');
    expect(continueButton, findsOneWidget);
    await tester.dragUntilVisible(
      continueButton,
      find.byType(Scrollable).first,
      const Offset(0, -200),
    );

    await tester.tap(continueButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('VIDEO_IMPORT_SCREEN'), findsOneWidget);
  });
}
