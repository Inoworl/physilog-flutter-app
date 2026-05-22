import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:physi_log/features/manage/domain/event_repository.dart';
import 'package:physi_log/models/event.dart';

class FirestoreEventRepository implements EventRepository {
  FirestoreEventRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String userId) {
    return _firestore.collection('users').doc(userId).collection('種目');
  }

  @override
  Future<List<Event>> getEvents({required String userId}) async {
    final snapshot = await _collection(userId)
        .where('deletedAt', isNull: true)
        .orderBy('sortOrder')
        .orderBy('name')
        .get();
    return snapshot.docs.map((doc) => Event.fromFirestore(doc)).toList();
  }

  @override
  Future<void> saveEvent(Event event) async {
    await _collection(event.userId).doc(event.id).set(event.toFirestore());
  }

  @override
  Future<void> updateEvent(Event event) async {
    await _collection(event.userId).doc(event.id).update(event.toFirestore());
  }

  @override
  Future<void> deleteEvent({required String userId, required String id}) async {
    await _collection(userId).doc(id).update({
      'deletedAt': Timestamp.fromDate(DateTime.now()),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }
}
