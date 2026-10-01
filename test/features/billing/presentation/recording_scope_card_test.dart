import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/app/overrides/in_memory_athlete_repository.dart';
import 'package:physi_log/app/overrides/in_memory_event_repository.dart';
import 'package:physi_log/app/overrides/in_memory_record_repository.dart';
import 'package:physi_log/features/billing/application/recording_access_providers.dart';
import 'package:physi_log/features/billing/application/recording_access_service.dart';
import 'package:physi_log/features/billing/domain/plan_access_policy.dart';
import 'package:physi_log/features/billing/presentation/recording_scope_card.dart';
import 'package:physi_log/providers/app_providers.dart';

import '../support/plan_fixture.dart';

void main() {
  testWidgets(
    'Account switching removes the old names from the selection dialog',
    (tester) async {
      final identity = StateProvider((ref) => 'fixture-owner');
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWith((ref) => ref.watch(identity)),
            planAccessStateProvider.overrideWithValue(
              fixturePlan(PlanTier.free),
            ),
            athleteRepositoryProvider.overrideWithValue(
              InMemoryAthleteRepository(fixtureAthletes()),
            ),
            eventRepositoryProvider.overrideWithValue(
              InMemoryEventRepository(fixtureEvents()),
            ),
            recordDataRepositoryProvider.overrideWithValue(
              InMemoryRecordRepository(),
            ),
            recordingSelectionRepositoryProvider.overrideWithValue(
              MemoryRecordingSelectionRepository(),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                container = ProviderScope.containerOf(context);
                return const Scaffold(body: RecordingScopeCard());
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('計測対象を選ぶ'));
      await tester.pumpAndSettle();
      expect(find.text('選手 1'), findsOneWidget);
      container.read(identity.notifier).state = 'other-owner';
      await tester.pumpAndSettle();
      expect(find.text('選手 1'), findsNothing);
      expect(find.text('選択を保存'), findsNothing);
      expect(find.text('アカウントが変わりました。画面を開き直してください。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Free user can select one athlete without deleting existing data',
    (tester) async {
      final storage = MemoryRecordingSelectionRepository();
      final service = RecordingAccessService(
        currentUserId: () => 'fixture-owner',
        currentPlan: () => fixturePlan(PlanTier.free),
        storeMode: 'fixture',
        athletes: InMemoryAthleteRepository(fixtureAthletes()),
        events: InMemoryEventRepository(fixtureEvents()),
        selections: storage,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue('fixture-owner'),
            planAccessStateProvider.overrideWithValue(
              fixturePlan(PlanTier.free),
            ),
            athleteRepositoryProvider.overrideWithValue(
              InMemoryAthleteRepository(fixtureAthletes()),
            ),
            eventRepositoryProvider.overrideWithValue(
              InMemoryEventRepository(fixtureEvents()),
            ),
            recordDataRepositoryProvider.overrideWithValue(
              InMemoryRecordRepository(),
            ),
            recordingAccessServiceProvider.overrideWithValue(service),
            recordingAccessProvider.overrideWith((ref) => service.load()),
          ],
          child: const MaterialApp(home: Scaffold(body: RecordingScopeCard())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('過去の記録'), findsOneWidget);
      await tester.tap(find.text('計測対象を選ぶ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('選手 1'));
      await tester.pump();
      final second = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, '選手 2'),
      );
      expect(second.onChanged, isNull);
      await tester.drag(
        find.byType(SingleChildScrollView).last,
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('種目 1'));
      await tester.tap(find.text('選択を保存'));
      await tester.pumpAndSettle();
      final access = await service.load();
      expect(access.scope.canRecord('athlete-0', 'event-0'), isTrue);
      expect(access.athletes, hasLength(6));
      expect(tester.takeException(), isNull);
    },
  );
}
