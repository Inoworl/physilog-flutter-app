import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:physi_log/features/manage/domain/athlete_repository.dart';
import 'package:physi_log/models/athlete.dart';

class FirestoreAthleteRepository implements AthleteRepository {
  FirestoreAthleteRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String userId) {
    return _firestore.collection('users').doc(userId).collection('選手');
  }

  @override
  Future<List<Athlete>> getAthletes({required String userId}) async {
    final snapshot = await _collection(
      userId,
    ).where('deletedAt', isNull: true).orderBy('name').get();
    return snapshot.docs.map((doc) => Athlete.fromFirestore(doc)).toList();
  }

  @override
  Future<void> saveAthlete(Athlete athlete) async {
    await _collection(
      athlete.userId,
    ).doc(athlete.id).set(athlete.toFirestore());
  }

  @override
  Future<void> updateAthlete(Athlete athlete) async {
    await _collection(
      athlete.userId,
    ).doc(athlete.id).update(athlete.toFirestore());
  }

  @override
  Future<void> deleteAthlete({
    required String userId,
    required String id,
  }) async {
    await _collection(userId).doc(id).update({
      'deletedAt': Timestamp.fromDate(DateTime.now()),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }
}
