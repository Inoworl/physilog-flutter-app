import 'package:physi_log/features/manage/domain/athlete_repository.dart';
import 'package:physi_log/models/athlete.dart';

class InMemoryAthleteRepository implements AthleteRepository {
  InMemoryAthleteRepository([List<Athlete>? initialAthletes])
    : _athletes = [...?initialAthletes];

  final List<Athlete> _athletes;

  @override
  Future<void> deleteAthlete({
    required String userId,
    required String id,
  }) async {
    _athletes.removeWhere((athlete) => athlete.id == id);
  }

  @override
  Future<List<Athlete>> getAthletes({required String userId}) async {
    return _athletes.where((athlete) => athlete.userId == userId).toList();
  }

  @override
  Future<void> saveAthlete(Athlete athlete) async {
    _athletes.add(athlete);
  }

  @override
  Future<void> updateAthlete(Athlete athlete) async {
    final index = _athletes.indexWhere((item) => item.id == athlete.id);
    if (index != -1) {
      _athletes[index] = athlete;
    }
  }
}
