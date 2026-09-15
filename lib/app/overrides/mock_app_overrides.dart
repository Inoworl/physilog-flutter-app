import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:physi_log/features/billing/application/recording_access_providers.dart';
import 'package:physi_log/features/billing/domain/plan_access_policy.dart';
import 'package:physi_log/features/billing/domain/plan_access_state.dart';
import 'package:physi_log/features/billing/domain/recording_scope.dart';
import 'package:physi_log/models/measurement_record.dart';
import 'package:physi_log/app/overrides/in_memory_athlete_repository.dart';
import 'package:physi_log/app/overrides/in_memory_event_repository.dart';
import 'package:physi_log/app/overrides/in_memory_record_repository.dart';
import 'package:physi_log/models/athlete.dart';
import 'package:physi_log/models/event.dart';
import 'package:physi_log/providers/app_providers.dart';

/// Firebase を使わない起動やテスト用に、主要 provider を in-memory 実装へ差し替える。
List<Override> mockAppOverrides({PlanTier? previewPlan}) {
  if (previewPlan != null) {
    if (kReleaseMode) {
      throw UnsupportedError(
        'Fixed plan previews are disabled in release builds.',
      );
    }
    return _planPreviewOverrides(previewPlan);
  }
  return [
    currentUserIdProvider.overrideWithValue('mock-user'),
    athleteRepositoryProvider.overrideWithValue(
      InMemoryAthleteRepository([
        Athlete(
          id: 'mock-athlete-1',
          userId: 'mock-user',
          name: '山田太郎',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      ]),
    ),
    eventRepositoryProvider.overrideWithValue(
      InMemoryEventRepository([
        Event(
          id: 'mock-event-1',
          userId: 'mock-user',
          name: '50m走',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      ]),
    ),
    recordRepositoryProvider.overrideWithValue(InMemoryRecordRepository()),
  ];
}

List<Override> _planPreviewOverrides(PlanTier tier) {
  final now = DateTime.now();
  final athletes = List.generate(
    6,
    (index) => Athlete(
      id: 'preview-athlete-$index',
      userId: 'mock-user',
      name: 'テスト選手${index + 1}',
      createdAt: now,
      updatedAt: now,
    ),
  );
  final events = List.generate(
    4,
    (index) => Event(
      id: 'preview-event-$index',
      userId: 'mock-user',
      name: '${[50, 100, 200, 400][index]}m走',
      unit: '秒',
      createdAt: now,
      updatedAt: now,
    ),
  );
  final records = List.generate(
    6,
    (index) => MeasurementRecord(
      id: 'preview-record-$index',
      userId: 'mock-user',
      athleteId: athletes[index].id,
      athleteName: athletes[index].name,
      eventId: events[index % events.length].id,
      eventType: events[index % events.length].name,
      startMs: 0,
      endMs: 10000 + index * 1000,
      durationMs: 10000 + index * 1000,
      measuredAt: now.subtract(Duration(days: index ~/ 3)),
      createdAt: now,
      updatedAt: now,
    ),
  );
  return [
    currentUserIdProvider.overrideWithValue('mock-user'),
    dataStoreModeProvider.overrideWithValue(DataStoreMode.local),
    planAccessStateProvider.overrideWithValue(
      PlanAccessReady(
        const PlanAccessPolicy().evaluate(
          hasRevenueCatPersonalFamily: tier == PlanTier.personalFamily,
          hasRevenueCatTeam: tier == PlanTier.team,
          hasLegacyPersonalFamily: false,
          hasLegacyTeam: false,
          hasManualTeam: false,
        ),
      ),
    ),
    athleteRepositoryProvider.overrideWithValue(
      InMemoryAthleteRepository(athletes),
    ),
    eventRepositoryProvider.overrideWithValue(InMemoryEventRepository(events)),
    recordDataRepositoryProvider.overrideWithValue(
      InMemoryRecordRepository(records),
    ),
    recordingSelectionRepositoryProvider.overrideWithValue(
      _PreviewRecordingSelections(),
    ),
  ];
}

class _PreviewRecordingSelections implements RecordingSelectionRepository {
  final _values = <String, RecordingSelection>{};

  @override
  Future<RecordingSelection> read(String owner) async =>
      _values[owner] ?? const RecordingSelection();

  @override
  Future<void> write(String owner, RecordingSelection selection) async {
    _values[owner] = selection;
  }
}
