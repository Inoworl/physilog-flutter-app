import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/billing/domain/plan_access_policy.dart';
import 'package:physi_log/features/billing/domain/recording_scope.dart';

void main() {
  final athletes = {
    'athlete-1',
    'athlete-2',
    'athlete-3',
    'athlete-4',
    'athlete-5',
    'athlete-6',
  };
  final events = {'event-1', 'event-2', 'event-3', 'event-4'};

  test('Free requires an explicit bounded selection after downgrade', () {
    final scope = RecordingScope.resolve(
      capabilities: PlanCapabilities.free,
      athleteIds: athletes,
      eventIds: events,
      selection: const RecordingSelection(),
    );
    expect(scope.requiresSelection, isTrue);
    expect(scope.canRecord('athlete-1', 'event-1'), isFalse);
    expect(scope.athleteIds, isEmpty);
  });

  test('Free permits only the chosen athlete and three events', () {
    final scope = RecordingScope.resolve(
      capabilities: PlanCapabilities.free,
      athleteIds: athletes,
      eventIds: events,
      selection: const RecordingSelection(
        athleteIds: {'athlete-2'},
        eventIds: {'event-1', 'event-2', 'event-3'},
      ),
    );
    expect(scope.canRecord('athlete-2', 'event-3'), isTrue);
    expect(scope.canRecord('athlete-1', 'event-3'), isFalse);
    expect(scope.canRecord('athlete-2', 'event-4'), isFalse);
    expect(scope.requiresSelection, isFalse);
  });

  test('Personal/family permits five athletes and all events', () {
    final scope = RecordingScope.resolve(
      capabilities: PlanCapabilities.personalFamily,
      athleteIds: athletes,
      eventIds: events,
      selection: RecordingSelection(athleteIds: athletes.take(5).toSet()),
    );
    expect(scope.athleteIds.length, 5);
    expect(scope.canRecord('athlete-5', 'event-4'), isTrue);
    expect(scope.canRecord('athlete-6', 'event-4'), isFalse);
  });

  test(
    'Team recovery restores all existing athletes without deleting a selection',
    () {
      const selection = RecordingSelection(
        athleteIds: {'athlete-2'},
        eventIds: {'event-1'},
      );
      final scope = RecordingScope.resolve(
        capabilities: PlanCapabilities.team,
        athleteIds: athletes,
        eventIds: events,
        selection: selection,
      );
      expect(scope.canRecord('athlete-6', 'event-4'), isTrue);
      expect(scope.requiresSelection, isFalse);
      expect(selection.athleteIds, {'athlete-2'});
    },
  );

  test('Stale or oversized selections never widen the new plan', () {
    final scope = RecordingScope.resolve(
      capabilities: PlanCapabilities.free,
      athleteIds: athletes,
      eventIds: events,
      selection: const RecordingSelection(
        athleteIds: {'athlete-1', 'athlete-2'},
        eventIds: {'removed'},
      ),
    );
    expect(scope.athleteIds, isEmpty);
    expect(scope.eventIds, isEmpty);
    expect(scope.canRecord(null, 'event-1'), isFalse);
    expect(scope.requiresSelection, isTrue);
  });

  test('Catalogs within the limit need no manual selection', () {
    final scope = RecordingScope.resolve(
      capabilities: PlanCapabilities.free,
      athleteIds: {'athlete-1'},
      eventIds: {'event-1', 'event-2', 'event-3'},
      selection: const RecordingSelection(),
    );
    expect(scope.canRecord('athlete-1', 'event-3'), isTrue);
    expect(scope.canRecord('not-owned', 'event-3'), isFalse);
    expect(scope.requiresSelection, isFalse);
  });
}
