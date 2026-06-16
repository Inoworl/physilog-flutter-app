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
}
