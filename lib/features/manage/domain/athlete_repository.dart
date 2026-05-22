import 'package:physi_log/models/athlete.dart';

abstract class AthleteRepository {
  Future<List<Athlete>> getAthletes({required String userId});
  Future<void> saveAthlete(Athlete athlete);
  Future<void> updateAthlete(Athlete athlete);
  Future<void> deleteAthlete({required String userId, required String id});
}
