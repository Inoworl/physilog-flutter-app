import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:physi_log/features/manage/domain/athlete_repository.dart';
import 'package:physi_log/features/records/domain/record_repository.dart';
import 'package:physi_log/models/athlete.dart';
import 'package:physi_log/models/measurement_record.dart';
import 'package:physi_log/providers/app_providers.dart';
import 'package:uuid/uuid.dart';

part 'athlete_list_notifier.freezed.dart';

@freezed
class AthleteListState with _$AthleteListState {
  const factory AthleteListState.loading() = _Loading;
  const factory AthleteListState.loaded({required List<Athlete> athletes}) =
      _Loaded;
  const factory AthleteListState.error(String message) = _Error;
}

final athleteListNotifierProvider =
    StateNotifierProvider<AthleteListNotifier, AthleteListState>((ref) {
      final repository = ref.watch(athleteRepositoryProvider);
      final recordRepository = ref.watch(recordRepositoryProvider);
      final userId = ref.watch(currentUserIdProvider);
      return AthleteListNotifier(
        repository: repository,
        recordRepository: recordRepository,
        userId: userId,
      );
    });

class AthleteListNotifier extends StateNotifier<AthleteListState> {
  AthleteListNotifier({
    required AthleteRepository repository,
    required RecordRepository recordRepository,
    required String? userId,
  }) : _repository = repository,
       _recordRepository = recordRepository,
       _userId = userId,
       super(const AthleteListState.loading()) {
    loadAthletes();
  }

  final AthleteRepository _repository;
  final RecordRepository _recordRepository;
  final String? _userId;
  final Uuid _uuid = const Uuid();

  Future<void> loadAthletes() async {
    if (_userId == null) {
      state = const AthleteListState.loaded(athletes: []);
      return;
    }

    state = const AthleteListState.loading();
    try {
      final athletes = await _repository.getAthletes(userId: _userId);
      final syncedAthletes = await _syncAthletesFromRecords(athletes);
      state = AthleteListState.loaded(athletes: syncedAthletes);
    } catch (e) {
      state = AthleteListState.error('選手データの読み込みに失敗しました: $e');
    }
  }

  Future<void> refresh() async {
    await loadAthletes();
  }

  Future<List<Athlete>> _syncAthletesFromRecords(List<Athlete> athletes) async {
    if (_userId == null) return athletes;

    final athletesById = <String, Athlete>{
      for (final athlete in athletes) athlete.id: athlete,
    };
    final athletesByName = <String, Athlete>{
      for (final athlete in athletes)
        _normalizeAthleteName(athlete.name): athlete,
    };

    final records = await _loadAllRecords();
    if (records.isEmpty) {
      final sorted =
          athletesById.values.toList()
            ..sort((a, b) => a.name.compareTo(b.name));
      return sorted;
    }

    final athletesToSave = <Athlete>[];
    final recordUpdates = <String, MeasurementRecord>{};

    for (final record in records) {
      final name = record.athleteName.trim();
      final normalizedName = _normalizeAthleteName(name);
      final recordAthleteId = record.athleteId?.trim();
      final hasAthleteId =
          recordAthleteId != null && recordAthleteId.isNotEmpty;

      Athlete? resolvedAthlete;
      if (hasAthleteId) {
        resolvedAthlete = athletesById[recordAthleteId];
        if (resolvedAthlete == null && normalizedName.isNotEmpty) {
          final sameNameAthlete = athletesByName[normalizedName];
          if (sameNameAthlete != null) {
            resolvedAthlete = sameNameAthlete;
          }
        }
      } else if (normalizedName.isNotEmpty) {
        resolvedAthlete = athletesByName[normalizedName];
        if (resolvedAthlete == null) {
          final now = DateTime.now();
          resolvedAthlete = Athlete(
            id: _uuid.v4(),
            userId: _userId,
            name: name,
            createdAt: now,
            updatedAt: now,
          );
          athletesById[resolvedAthlete.id] = resolvedAthlete;
          athletesByName[normalizedName] = resolvedAthlete;
          athletesToSave.add(resolvedAthlete);
        }
      }

      if (resolvedAthlete == null) continue;
      if (record.athleteId != resolvedAthlete.id ||
          record.athleteName != resolvedAthlete.name) {
        recordUpdates[record.id] = record.copyWith(
          athleteId: resolvedAthlete.id,
          athleteName: resolvedAthlete.name,
          updatedAt: DateTime.now(),
        );
      }
    }

    for (final athlete in athletesToSave) {
      await _repository.saveAthlete(athlete);
    }
    for (final updatedRecord in recordUpdates.values) {
      await _recordRepository.updateRecord(updatedRecord);
    }

    final sorted =
        athletesById.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    return sorted;
  }

  String _normalizeAthleteName(String name) => name.trim().toLowerCase();

  Future<List<MeasurementRecord>> _loadAllRecords() async {
    if (_userId == null) return const <MeasurementRecord>[];
    const pageSize = 200;
    final result = <MeasurementRecord>[];
    MeasurementRecord? lastRecord;

    while (true) {
      final page = await _recordRepository.getRecords(
        userId: _userId,
        limit: pageSize,
        lastRecord: lastRecord,
      );
      if (page.isEmpty) break;
      result.addAll(page);
      if (page.length < pageSize) break;
      lastRecord = page.last;
    }

    return result;
  }

  Future<Athlete?> addAthlete(String name) async {
    final trimmed = name.trim();
    if (_userId == null || trimmed.isEmpty) return null;

    final now = DateTime.now();
    final athlete = Athlete(
      id: const Uuid().v4(),
      userId: _userId,
      name: trimmed,
      createdAt: now,
      updatedAt: now,
    );

    await _repository.saveAthlete(athlete);
    await loadAthletes();
    return athlete;
  }

  Future<Athlete?> updateAthlete({
    required String athleteId,
    required String name,
  }) async {
    final trimmed = name.trim();
    if (_userId == null || trimmed.isEmpty) return null;

    final current = await _repository.getAthletes(userId: _userId);
    Athlete? existing;
    for (final athlete in current) {
      if (athlete.id == athleteId) {
        existing = athlete;
        break;
      }
    }
    if (existing == null) return null;

    final updated = existing.copyWith(name: trimmed, updatedAt: DateTime.now());
    await _repository.updateAthlete(updated);
    await loadAthletes();
    return updated;
  }

  Future<void> deleteAthlete(String athleteId) async {
    await _repository.deleteAthlete(athleteId);
    await loadAthletes();
  }
}
