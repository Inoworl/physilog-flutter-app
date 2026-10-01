import 'package:physi_log/features/billing/domain/plan_access_policy.dart';
import 'package:physi_log/features/billing/domain/plan_access_state.dart';
import 'package:physi_log/features/billing/domain/recording_scope.dart';
import 'package:physi_log/models/athlete.dart';
import 'package:physi_log/models/event.dart';
import 'package:physi_log/models/measurement_record.dart';

PlanAccessReady fixturePlan(PlanTier tier) => PlanAccessReady(
  const PlanAccessPolicy().evaluate(
    hasRevenueCatPersonalFamily: tier == PlanTier.personalFamily,
    hasRevenueCatTeam: tier == PlanTier.team,
    hasLegacyPersonalFamily: false,
    hasLegacyTeam: false,
    hasManualTeam: false,
  ),
);

final fixtureDate = DateTime.utc(2026, 1, 1);

List<Athlete> fixtureAthletes({
  int count = 6,
  String owner = 'fixture-owner',
}) => List.generate(
  count,
  (index) => Athlete(
    id: 'athlete-$index',
    userId: owner,
    name: '選手 ${index + 1}',
    createdAt: fixtureDate,
    updatedAt: fixtureDate,
  ),
);

List<Event> fixtureEvents({int count = 4, String owner = 'fixture-owner'}) =>
    List.generate(
      count,
      (index) => Event(
        id: 'event-$index',
        userId: owner,
        name: '種目 ${index + 1}',
        unit: '秒',
        createdAt: fixtureDate,
        updatedAt: fixtureDate,
      ),
    );

MeasurementRecord fixtureRecord({
  String id = 'record',
  String owner = 'fixture-owner',
  String athleteId = 'athlete-0',
  String eventId = 'event-0',
}) => MeasurementRecord(
  id: id,
  userId: owner,
  athleteId: athleteId,
  eventId: eventId,
  athleteName: '選手 1',
  eventType: '種目 1',
  startMs: 0,
  endMs: 1234,
  durationMs: 1234,
  measuredAt: fixtureDate,
  createdAt: fixtureDate,
  updatedAt: fixtureDate,
);

class MemoryRecordingSelectionRepository
    implements RecordingSelectionRepository {
  final values = <String, RecordingSelection>{};
  @override
  Future<RecordingSelection> read(String owner) async =>
      values[owner] ?? const RecordingSelection();
  @override
  Future<void> write(String owner, RecordingSelection selection) async {
    values[owner] = selection;
  }
}
