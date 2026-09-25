import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:physi_log/app/overrides/in_memory_athlete_repository.dart';
import 'package:physi_log/app/overrides/in_memory_event_repository.dart';
import 'package:physi_log/app/overrides/in_memory_record_repository.dart';
import 'package:physi_log/features/billing/application/recording_access_providers.dart';
import 'package:physi_log/features/billing/domain/plan_access_policy.dart';
import 'package:physi_log/features/billing/domain/plan_access_state.dart';
import 'package:physi_log/features/measurement/presentation/measurement_session_screen.dart';
import 'package:physi_log/features/measurement/presentation/widgets/session_keypad.dart';
import 'package:physi_log/models/event.dart';
import 'package:physi_log/providers/app_providers.dart';

import '../../billing/support/plan_fixture.dart';

void main() {
  for (final adopt in [false, true]) {
    testWidgets(
      adopt
          ? 'Team expiry during adoption preserves the previous record and feedback'
          : 'Team expiry during manual entry preserves input and offers plan settings',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 1100));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final plan = StateProvider<PlanAccessState>(
          (ref) => fixturePlan(PlanTier.team),
        );
        final records = InMemoryRecordRepository();
        final event = fixtureEvents(
          count: 1,
        ).single.copyWith(measurementMethod: EventMeasurementMethod.manual);
        final container = ProviderContainer(
          overrides: [
            currentUserIdProvider.overrideWithValue('fixture-owner'),
            planAccessStateProvider.overrideWith((ref) => ref.watch(plan)),
            athleteRepositoryProvider.overrideWithValue(
              InMemoryAthleteRepository(fixtureAthletes(count: 1)),
            ),
            eventRepositoryProvider.overrideWithValue(
              InMemoryEventRepository([event]),
            ),
            recordDataRepositoryProvider.overrideWithValue(records),
            recordingSelectionRepositoryProvider.overrideWithValue(
              MemoryRecordingSelectionRepository(),
            ),
          ],
        );
        addTearDown(container.dispose);
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) =>
                  MeasurementSessionScreen(event: event, date: fixtureDate),
            ),
            GoRoute(
              path: '/plan',
              name: 'settingsPlan',
              builder: (context, state) => const Scaffold(body: Text('プラン画面')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        if (adopt) {
          await tester.tap(find.text('1').last);
          await tester.pump();
          await tester.tap(find.text('保存して次へ'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('2').last);
          await tester.pump();
          await tester.tap(find.text('保存して次へ'));
          await tester.pumpAndSettle();
          expect(find.text('今回を採用'), findsOneWidget);
        } else {
          await tester.tap(find.text('2').last);
        }
        container.read(plan.notifier).state = fixturePlan(PlanTier.free);
        await tester.pumpAndSettle();
        await tester.tap(find.text(adopt ? '今回を採用' : '保存して次へ'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.textContaining('保存できませんでした'), findsOneWidget);
        expect(find.textContaining('計測会はTeamプラン'), findsOneWidget);
        final saved = await records.getAllRecords(userId: 'fixture-owner');
        if (adopt) {
          expect(saved.single.effectiveRecordValue, 1);
          expect(find.text('今回を採用'), findsOneWidget);
        } else {
          expect(saved, isEmpty);
          expect(
            tester.widget<SessionKeypad>(find.byType(SessionKeypad)).input,
            '2',
          );
        }
        await tester.tap(find.text('プランを確認'));
        await tester.pumpAndSettle();
        expect(find.text('プラン画面'), findsOneWidget);
      },
    );
  }
}
