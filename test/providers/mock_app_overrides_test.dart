import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/billing/application/recording_access_providers.dart';
import 'package:physi_log/features/billing/domain/plan_access_policy.dart';
import 'package:physi_log/features/billing/domain/plan_access_state.dart';
import 'package:physi_log/features/billing/domain/recording_scope.dart';
import 'package:physi_log/app/overrides/mock_app_overrides.dart';
import 'package:physi_log/providers/app_providers.dart';

void main() {
  for (final tier in PlanTier.values) {
    test(
      'Fixed $tier preview has boundary data and real write guards without login',
      () async {
        final container = ProviderContainer(
          overrides: mockAppOverrides(previewPlan: tier),
        );
        addTearDown(container.dispose);
        final plan = container.read(planAccessStateProvider) as PlanAccessReady;
        expect(plan.tier, tier);
        expect(
          await container
              .read(athleteRepositoryProvider)
              .getAthletes(userId: 'mock-user'),
          hasLength(6),
        );
        expect(
          await container
              .read(eventRepositoryProvider)
              .getEvents(userId: 'mock-user'),
          hasLength(4),
        );
        final records = await container
            .read(recordRepositoryProvider)
            .getAllRecords(userId: 'mock-user');
        expect(records, hasLength(6));
        final candidate = records.last.copyWith(id: 'new-preview-record');
        if (tier == PlanTier.team) {
          await container.read(recordRepositoryProvider).saveRecord(candidate);
          expect(
            await container
                .read(recordRepositoryProvider)
                .getAllRecords(userId: 'mock-user'),
            hasLength(7),
          );
        } else {
          await expectLater(
            container.read(recordRepositoryProvider).saveRecord(candidate),
            throwsA(isA<PlanAccessException>()),
          );
          await container
              .read(recordingAccessServiceProvider)
              .select(
                RecordingSelection(
                  athleteIds: {candidate.athleteId!},
                  eventIds: {candidate.eventId!},
                ),
              );
          await container.read(recordRepositoryProvider).saveRecord(candidate);
        }
      },
    );
  }

  test('mockAppOverridesはrecord/athlete/event/currentUserIdを差し替える', () {
    final container = ProviderContainer(overrides: mockAppOverrides());
    addTearDown(container.dispose);

    expect(container.read(currentUserIdProvider), 'mock-user');
    expect(
      container.read(recordRepositoryProvider).runtimeType.toString(),
      'InMemoryRecordRepository',
    );
    expect(
      container.read(athleteRepositoryProvider).runtimeType.toString(),
      'InMemoryAthleteRepository',
    );
    expect(
      container.read(eventRepositoryProvider).runtimeType.toString(),
      'InMemoryEventRepository',
    );
  });
}
