import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:physi_log/features/auth/domain/user_metadata_repository.dart';

class FirestoreUserMetadataRepository implements UserMetadataRepository {
  FirestoreUserMetadataRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _userDoc(String userId) {
    return _firestore.collection('users').doc(userId);
  }

  @override
  Future<void> ensureAnonymousUserCreated({required String userId}) async {
    final doc = _userDoc(userId);
    final snapshot = await doc.get();
    if (snapshot.exists) {
      return;
    }

    await doc.set({
      'createdAt': FieldValue.serverTimestamp(),
      'authProvider': 'anonymous',
      'emailLinkedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> markEmailLinked({required String userId}) async {
    await _userDoc(userId).set({
      'authProvider': 'email',
      'emailLinkedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> deleteUserData({required String userId}) async {
    final userDoc = _userDoc(userId);
    for (final collectionName in ['athletes', 'events', 'records']) {
      await _deleteCollection(userDoc.collection(collectionName));
    }
    await userDoc.delete();
  }

  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    QuerySnapshot<Map<String, dynamic>> snapshot;
    do {
      snapshot = await collection.limit(400).get();
      if (snapshot.docs.isEmpty) {
        return;
      }

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } while (snapshot.docs.length == 400);
  }
}
