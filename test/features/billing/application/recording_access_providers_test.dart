import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/app/overrides/in_memory_athlete_repository.dart';
import 'package:physi_log/app/overrides/in_memory_event_repository.dart';
import 'package:physi_log/app/overrides/in_memory_record_repository.dart';
import 'package:physi_log/features/billing/application/recording_access_providers.dart';
import 'package:physi_log/features/billing/domain/plan_access_policy.dart';
import 'package:physi_log/features/billing/domain/recording_scope.dart';
import 'package:physi_log/features/measurement/application/measurement_session_notifier.dart';
import 'package:physi_log/providers/app_providers.dart';

import '../support/plan_fixture.dart';

void main() {
  test(
    'Entry controls stop offering out-of-plan targets after downgrade',
    () async {
      final tier = StateProvider((ref) => PlanTier.team);
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue('fixture-owner'),
          planAccessStateProvider.overrideWith(
            (ref) => fixturePlan(ref.watch(tier)),
          ),
          recordDataRepositoryProvider.overrideWithValue(
            InMemoryRecordRepository(),
          ),
          athleteRepositoryProvider.overrideWithValue(
            InMemoryAthleteRepository(fixtureAthletes()),
          ),
          eventRepositoryProvider.overrideWithValue(
            InMemoryEventRepository(fixtureEvents()),
          ),
          recordingSelectionRepositoryProvider.overrideWithValue(
            MemoryRecordingSelectionRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(recordingScopeStateProvider);
      await Future<void>.delayed(Duration.zero);
      expect(
        container
            .read(recordingScopeStateProvider)
            ?.canRecord('athlete-5', 'event-3'),
        isTrue,
      );
      container.read(tier.notifier).state = PlanTier.free;
      expect(
        container
                .read(recordingScopeStateProvider)
                ?.canRecord('athlete-5', 'event-3') ??
            false,
        isFalse,
      );
      await container.read(recordingAccessProvider.future);
      await container
          .read(recordingAccessServiceProvider)
          .select(
            const RecordingSelection(
              athleteIds: {'athlete-1'},
              eventIds: {'event-1'},
            ),
          );
      container.invalidate(recordingAccessProvider);
      await container.read(recordingAccessProvider.future);
      expect(
        container
            .read(recordingScopeStateProvider)
            ?.canRecord('athlete-1', 'event-1'),
        isTrue,
      );
      expect(
        container
            .read(recordingScopeStateProvider)
            ?.canRecord('athlete-5', 'event-3'),
        isFalse,
      );
    },
  );

  test(
    'Production provider wiring blocks a formerly valid Team record after downgrade',
    () async {
      final tier = StateProvider((ref) => PlanTier.team);
      final data = InMemoryRecordRepository();
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue('fixture-owner'),
          planAccessStateProvider.overrideWith(
            (ref) => fixturePlan(ref.watch(tier)),
          ),
          recordDataRepositoryProvider.overrideWithValue(data),
          athleteRepositoryProvider.overrideWithValue(
            InMemoryAthleteRepository(fixtureAthletes()),
          ),
          eventRepositoryProvider.overrideWithValue(
            InMemoryEventRepository(fixtureEvents()),
          ),
          recordingSelectionRepositoryProvider.overrideWithValue(
            MemoryRecordingSelectionRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final repository = container.read(recordRepositoryProvider);
      await repository.saveRecord(fixtureRecord());
      container.read(tier.notifier).state = PlanTier.free;
      await expectLater(
        repository.saveRecord(fixtureRecord(id: 'blocked')),
        throwsA(isA<PlanAccessException>()),
      );
      expect(await data.getAllRecords(userId: 'fixture-owner'), hasLength(1));
    },
  );

  test(
    'An active session rechecks Team even when updating an existing attempt',
    () async {
      var hasTeam = true;
      final data = InMemoryRecordRepository();
      final notifier = MeasurementSessionNotifier(
        repository: data,
        userId: 'fixture-owner',
        event: fixtureEvents().first,
        beforeAttempt: () async {
          if (!hasTeam) throw const PlanAccessException('Team required');
        },
      );
      addTearDown(notifier.dispose);
      await Future<void>.delayed(Duration.zero);
      await notifier.recordAttempt(
        athleteId: 'athlete-0',
        athleteName: '選手 1',
        value: 12,
      );
      hasTeam = false;
      await expectLater(
        notifier.recordAttempt(
          athleteId: 'athlete-0',
          athleteName: '選手 1',
          value: 10,
        ),
        throwsA(isA<PlanAccessException>()),
      );
      expect(
        (await data.getAllRecords(
          userId: 'fixture-owner',
        )).single.effectiveRecordValue,
        12,
      );
    },
  );
}
