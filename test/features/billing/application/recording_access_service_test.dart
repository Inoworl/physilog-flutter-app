import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/app/overrides/in_memory_athlete_repository.dart';
import 'package:physi_log/app/overrides/in_memory_event_repository.dart';
import 'package:physi_log/app/overrides/in_memory_record_repository.dart';
import 'package:physi_log/features/billing/application/recording_access_service.dart';
import 'package:physi_log/features/billing/data/plan_limited_record_repository.dart';
import 'package:physi_log/features/billing/domain/plan_access_policy.dart';
import 'package:physi_log/features/billing/domain/plan_access_state.dart';
import 'package:physi_log/features/billing/domain/recording_scope.dart';

import '../support/plan_fixture.dart';

void main() {
  late PlanAccessState plan;
  late String? owner;
  late MemoryRecordingSelectionRepository selections;
  late RecordingAccessService service;
  late InMemoryRecordRepository records;
  late PlanLimitedRecordRepository guarded;

  setUp(() {
    plan = fixturePlan(PlanTier.team);
    owner = 'fixture-owner';
    selections = MemoryRecordingSelectionRepository();
    service = RecordingAccessService(
      currentUserId: () => owner,
      currentPlan: () => plan,
      storeMode: 'fixture',
      athletes: InMemoryAthleteRepository(fixtureAthletes()),
      events: InMemoryEventRepository(fixtureEvents()),
      selections: selections,
    );
    records = InMemoryRecordRepository([fixtureRecord()]);
    guarded = PlanLimitedRecordRepository(repository: records, access: service);
  });

  test('An open recording form cannot save after Team expires', () async {
    await guarded.saveRecord(
      fixtureRecord(id: 'team-record', athleteId: 'athlete-5'),
    );
    plan = fixturePlan(PlanTier.free);
    await expectLater(
      guarded.saveRecord(fixtureRecord(id: 'blocked', athleteId: 'athlete-5')),
      throwsA(isA<PlanAccessException>()),
    );
    expect(await records.getRecord(userId: owner!, id: 'blocked'), isNull);
    expect(await guarded.getAllRecords(userId: owner!), hasLength(2));
    await guarded.deleteRecord(userId: owner!, id: 'team-record');
    expect(await guarded.getAllRecords(userId: owner!), hasLength(1));
  });

  test(
    'A valid selection enables only its chosen records after downgrade',
    () async {
      plan = fixturePlan(PlanTier.free);
      await service.select(
        const RecordingSelection(
          athleteIds: {'athlete-0'},
          eventIds: {'event-0', 'event-1', 'event-2'},
        ),
      );
      await guarded.saveRecord(fixtureRecord(id: 'allowed'));
      await expectLater(
        guarded.updateRecord(fixtureRecord(athleteId: 'athlete-5')),
        throwsA(isA<PlanAccessException>()),
      );
      plan = fixturePlan(PlanTier.team);
      await guarded.saveRecord(
        fixtureRecord(
          id: 'recovered',
          athleteId: 'athlete-5',
          eventId: 'event-3',
        ),
      );
      expect(await records.getAllRecords(userId: owner!), hasLength(3));
    },
  );

  test('Personal/family selection allows five athletes, not six', () async {
    plan = fixturePlan(PlanTier.personalFamily);
    await service.select(
      RecordingSelection(
        athleteIds: fixtureAthletes(
          count: 5,
        ).map((athlete) => athlete.id).toSet(),
      ),
    );
    await guarded.saveRecord(
      fixtureRecord(id: 'fifth', athleteId: 'athlete-4', eventId: 'event-3'),
    );
    await expectLater(
      guarded.saveRecord(fixtureRecord(id: 'sixth', athleteId: 'athlete-5')),
      throwsA(isA<PlanAccessException>()),
    );
  });

  test('Invalid or oversized selections are not persisted', () async {
    plan = fixturePlan(PlanTier.free);
    await expectLater(
      service.select(
        const RecordingSelection(athleteIds: {'athlete-0', 'athlete-1'}),
      ),
      throwsA(isA<PlanAccessException>()),
    );
    await expectLater(
      service.select(const RecordingSelection(athleteIds: {'other-owner'})),
      throwsA(isA<PlanAccessException>()),
    );
    expect(selections.values, isEmpty);
  });

  test(
    'Loading and failed access deny writes without hiding history',
    () async {
      for (final unavailable in [
        const PlanAccessLoading(),
        const PlanAccessError(),
      ]) {
        plan = unavailable;
        await expectLater(
          guarded.saveRecord(fixtureRecord(id: 'blocked')),
          throwsA(isA<PlanAccessException>()),
        );
        expect(await guarded.getAllRecords(userId: owner!), hasLength(1));
      }
    },
  );

  test(
    'Owner changes reject stale form submissions and use separate selections',
    () async {
      plan = fixturePlan(PlanTier.free);
      await service.select(
        const RecordingSelection(
          athleteIds: {'athlete-0'},
          eventIds: {'event-0'},
        ),
      );
      owner = 'another-fixture';
      await expectLater(
        guarded.saveRecord(fixtureRecord()),
        throwsA(isA<PlanAccessException>()),
      );
      expect((await service.load()).scope.athleteIds, isEmpty);
    },
  );

  test(
    'Team-only session capability and creation limits are checked at action time',
    () async {
      await service.requireTeam();
      plan = fixturePlan(PlanTier.personalFamily);
      await expectLater(
        service.requireTeam(),
        throwsA(isA<PlanAccessException>()),
      );
      await expectLater(
        service.requireAthleteCreation(),
        throwsA(isA<PlanAccessException>()),
      );
      await service.requireEventCreation();
      plan = fixturePlan(PlanTier.free);
      await expectLater(
        service.requireEventCreation(),
        throwsA(isA<PlanAccessException>()),
      );
    },
  );

  test(
    'Changing the plan while loading data cannot retain an old Team decision',
    () async {
      final pending = service.load();
      plan = fixturePlan(PlanTier.free);
      expect((await pending).scope.requiresSelection, isTrue);
    },
  );

  test(
    'A switched identity during an asynchronous catalog load is rejected',
    () async {
      final pending = service.load();
      owner = 'another-fixture';
      await expectLater(pending, throwsA(isA<PlanAccessException>()));
    },
  );
}
