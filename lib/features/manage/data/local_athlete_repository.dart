import 'package:hive/hive.dart';
import 'package:physi_log/features/manage/domain/athlete_repository.dart';
import 'package:physi_log/models/athlete.dart';

class LocalAthleteRepository implements AthleteRepository {
  static const _boxName = 'athletes';
  Box<Map>? _box;

  Future<Box<Map>> get box async {
    _box ??= await Hive.openBox<Map>(_boxName);
    return _box!;
  }

  @override
  Future<List<Athlete>> getAthletes({required String userId}) async {
    final b = await box;
    final athletes = b.values
        .map((m) => Athlete.fromJson(Map<String, dynamic>.from(m)))
        .where((athlete) => athlete.userId == userId)
        .toList();
    athletes.sort((a, b) => a.name.compareTo(b.name));
    return athletes;
  }

  @override
  Future<void> saveAthlete(Athlete athlete) async {
    final b = await box;
    await b.put(athlete.id, athlete.toJson());
  }

  @override
  Future<void> updateAthlete(Athlete athlete) async {
    final b = await box;
    await b.put(athlete.id, athlete.toJson());
  }

  @override
  Future<void> deleteAthlete(String id) async {
    final b = await box;
    await b.delete(id);
  }
}
