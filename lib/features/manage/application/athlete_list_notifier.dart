import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:physi_log/features/manage/domain/athlete_repository.dart';
import 'package:physi_log/models/athlete.dart';
import 'package:physi_log/providers/app_providers.dart';
import 'package:physi_log/providers/repository_providers.dart';
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
      final userId = ref.watch(currentUserIdProvider);
      return AthleteListNotifier(repository: repository, userId: userId);
    });

class AthleteListNotifier extends StateNotifier<AthleteListState> {
  AthleteListNotifier({
    required AthleteRepository repository,
    required String? userId,
  }) : _repository = repository,
       _userId = userId,
       super(const AthleteListState.loading()) {
    loadAthletes();
  }

  final AthleteRepository _repository;
  final String? _userId;

  Future<void> loadAthletes() async {
    if (_userId == null) {
      state = const AthleteListState.loaded(athletes: []);
      return;
    }

    state = const AthleteListState.loading();
    try {
      final athletes = await _repository.getAthletes(userId: _userId);
      state = AthleteListState.loaded(athletes: athletes);
    } catch (e) {
      state = AthleteListState.error('選手データの読み込みに失敗しました: $e');
    }
  }

  Future<void> refresh() async {
    await loadAthletes();
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
