import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/app/overrides/in_memory_athlete_repository.dart';
import 'package:physi_log/app/overrides/in_memory_event_repository.dart';
import 'package:physi_log/app/overrides/in_memory_record_repository.dart';
import 'package:physi_log/features/billing/application/recording_access_providers.dart';
import 'package:physi_log/features/billing/domain/plan_access_policy.dart';
import 'package:physi_log/features/manage/application/athlete_list_notifier.dart';
import 'package:physi_log/features/records/application/record_csv_providers.dart';
import 'package:physi_log/features/records/data/record_csv_sharer.dart';
import 'package:physi_log/features/records/domain/record_csv.dart';
import 'package:physi_log/features/records/presentation/record_csv_export_button.dart';
import 'package:physi_log/providers/app_providers.dart';

import '../../billing/support/plan_fixture.dart';

void main() {
  testWidgets('Removing the selected athlete invalidates the export preview', (
    tester,
  ) async {
    final athletes = InMemoryAthleteRepository(fixtureAthletes(count: 1));
    final sharer = _FakeSharer();
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('fixture-owner'),
          planAccessStateProvider.overrideWithValue(fixturePlan(PlanTier.team)),
          recordDataRepositoryProvider.overrideWithValue(
            InMemoryRecordRepository([fixtureRecord()]),
          ),
          athleteRepositoryProvider.overrideWithValue(athletes),
          eventRepositoryProvider.overrideWithValue(
            InMemoryEventRepository(fixtureEvents(count: 1)),
          ),
          recordingSelectionRepositoryProvider.overrideWithValue(
            MemoryRecordingSelectionRepository(),
          ),
          recordCsvSharerProvider.overrideWithValue(sharer),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              container = ProviderScope.containerOf(context);
              return const Scaffold(body: RecordCsvExportButton());
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('CSV出力'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('選手 1').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('対象を確認'));
    await tester.pumpAndSettle();
    await athletes.deleteAthlete(
      userId: 'fixture-owner',
      id: fixtureAthletes(count: 1).single.id,
    );
    container.invalidate(athleteListNotifierProvider);
    await tester.pumpAndSettle();
    expect(find.text('CSVを保存・共有'), findsNothing);
    expect(find.text('選択した選手・種目が変更されました。条件を選び直してください。'), findsOneWidget);
    await tester.tap(find.text('条件をリセット'));
    await tester.pumpAndSettle();
    expect(find.text('対象を確認'), findsOneWidget);
    expect(sharer.calls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Switching accounts with a filtered preview open clears the export UI',
    (tester) async {
      final identity = StateProvider((ref) => 'fixture-owner');
      final sharer = _FakeSharer();
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWith((ref) => ref.watch(identity)),
            planAccessStateProvider.overrideWithValue(
              fixturePlan(PlanTier.team),
            ),
            recordDataRepositoryProvider.overrideWithValue(
              InMemoryRecordRepository([fixtureRecord()]),
            ),
            athleteRepositoryProvider.overrideWithValue(
              InMemoryAthleteRepository(fixtureAthletes(count: 1)),
            ),
            eventRepositoryProvider.overrideWithValue(
              InMemoryEventRepository(fixtureEvents(count: 1)),
            ),
            recordingSelectionRepositoryProvider.overrideWithValue(
              MemoryRecordingSelectionRepository(),
            ),
            recordCsvSharerProvider.overrideWithValue(sharer),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                container = ProviderScope.containerOf(context);
                return const Scaffold(body: RecordCsvExportButton());
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('CSV出力'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('選手 1').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('対象を確認'));
      await tester.pumpAndSettle();
      container.read(identity.notifier).state = 'other-owner';
      await tester.pumpAndSettle();
      expect(find.text('CSVを保存・共有'), findsNothing);
      expect(find.text('アカウントが変わりました。出力画面を開き直してください。'), findsOneWidget);
      expect(sharer.calls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Free sees the Team upgrade prompt instead of an export dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          planAccessStateProvider.overrideWithValue(fixturePlan(PlanTier.free)),
        ],
        child: const MaterialApp(home: Scaffold(body: RecordCsvExportButton())),
      ),
    );
    await tester.tap(find.byTooltip('CSV出力'));
    await tester.pumpAndSettle();
    expect(find.text('Teamプランの機能です'), findsOneWidget);
    expect(find.text('プランを見る'), findsOneWidget);
    expect(find.text('対象を確認'), findsNothing);
  });

  testWidgets(
    'Team reviews the record count and privacy notice before sharing',
    (tester) async {
      final sharer = _FakeSharer();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue('fixture-owner'),
            planAccessStateProvider.overrideWithValue(
              fixturePlan(PlanTier.team),
            ),
            recordDataRepositoryProvider.overrideWithValue(
              InMemoryRecordRepository([fixtureRecord()]),
            ),
            athleteRepositoryProvider.overrideWithValue(
              InMemoryAthleteRepository(fixtureAthletes(count: 1)),
            ),
            eventRepositoryProvider.overrideWithValue(
              InMemoryEventRepository(fixtureEvents(count: 1)),
            ),
            recordingSelectionRepositoryProvider.overrideWithValue(
              MemoryRecordingSelectionRepository(),
            ),
            recordCsvSharerProvider.overrideWithValue(sharer),
          ],
          child: const MaterialApp(
            home: Scaffold(body: RecordCsvExportButton()),
          ),
        ),
      );
      await tester.tap(find.byTooltip('CSV出力'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('対象を確認'));
      await tester.pumpAndSettle();
      expect(find.text('1件の記録を出力します'), findsOneWidget);
      expect(find.textContaining('選手名'), findsOneWidget);
      expect(sharer.calls, 0);
      await tester.tap(find.text('CSVを保存・共有'));
      await tester.pumpAndSettle();
      expect(sharer.calls, 1);
      expect(sharer.origin!.width, greaterThan(0));
      expect(find.text('1件の記録を出力します'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

class _FakeSharer extends RecordCsvSharer {
  int calls = 0;
  Rect? origin;
  @override
  Future<void> share(
    RecordCsv document, {
    required Rect origin,
    required void Function() authorize,
  }) async {
    authorize();
    calls++;
    this.origin = origin;
  }
}
