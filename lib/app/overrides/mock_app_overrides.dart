import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:physi_log/app/overrides/in_memory_athlete_repository.dart';
import 'package:physi_log/app/overrides/in_memory_event_repository.dart';
import 'package:physi_log/app/overrides/in_memory_record_repository.dart';
import 'package:physi_log/models/athlete.dart';
import 'package:physi_log/models/event.dart';
import 'package:physi_log/providers/app_providers.dart';

/// Firebase を使わない起動やテスト用に、主要 provider を in-memory 実装へ差し替える。
List<Override> mockAppOverrides() {
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
