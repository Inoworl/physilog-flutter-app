import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:physi_log/features/entitlements/domain/entitlement_repository.dart';
import 'package:physi_log/models/entitlement.dart';

class FirestoreEntitlementRepository implements EntitlementRepository {
  FirestoreEntitlementRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _currentDocument(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('entitlements')
        .doc('current');
  }

  @override
  Future<Entitlement?> getCurrentEntitlement({required String userId}) async {
    final snapshot = await _currentDocument(userId).get();
    if (!snapshot.exists) {
      return null;
    }
    return Entitlement.fromFirestore(snapshot);
  }
}
