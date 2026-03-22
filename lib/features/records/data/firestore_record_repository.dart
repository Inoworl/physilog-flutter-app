import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:physi_log/features/records/domain/record_filter.dart';
import 'package:physi_log/features/records/domain/record_repository.dart';
import 'package:physi_log/models/measurement_record.dart';

class FirestoreRecordRepository implements RecordRepository {
  FirestoreRecordRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String userId) {
    return _firestore.collection('users').doc(userId).collection('records');
  }

  @override
  Future<List<MeasurementRecord>> getRecords({
    required String userId,
    RecordFilter? filter,
    int limit = 20,
    MeasurementRecord? lastRecord,
  }) async {
    Query<Map<String, dynamic>> query = _collection(userId);

    if (filter != null) {
      if (filter.athleteId != null && filter.athleteId!.isNotEmpty) {
        query = query.where('athleteId', isEqualTo: filter.athleteId);
      }
      if (filter.athleteName != null && filter.athleteName!.isNotEmpty) {
        query = query.where('athleteName', isEqualTo: filter.athleteName);
      }
      if (filter.eventType != null && filter.eventType!.isNotEmpty) {
        query = query.where('eventType', isEqualTo: filter.eventType);
      }
      if (filter.dateFrom != null) {
        query = query.where(
          'measuredAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(filter.dateFrom!),
        );
      }
      if (filter.dateTo != null) {
        final endOfDay = filter.dateTo!.add(const Duration(days: 1));
        query = query.where(
          'measuredAt',
          isLessThan: Timestamp.fromDate(endOfDay),
        );
      }
    }

    final sortKey = filter?.sortKey ?? RecordSortKey.measuredAtDesc;
    switch (sortKey) {
      case RecordSortKey.measuredAtDesc:
        query = query.orderBy('measuredAt', descending: true);
      case RecordSortKey.measuredAtAsc:
        query = query.orderBy('measuredAt');
      case RecordSortKey.durationAsc:
        query = query.orderBy('durationMs');
      case RecordSortKey.durationDesc:
        query = query.orderBy('durationMs', descending: true);
      case RecordSortKey.athleteName:
        query = query.orderBy('athleteName');
    }

    query = query.limit(limit);

    if (lastRecord != null) {
      final lastDoc = await _collection(userId).doc(lastRecord.id).get();
      if (lastDoc.exists) {
        query = query.startAfterDocument(lastDoc);
      }
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => MeasurementRecord.fromFirestore(doc))
        .toList();
  }

  @override
  Future<MeasurementRecord?> getRecord(String id) async {
    final doc = await _findRecordDocById(id);
    if (doc == null || !doc.exists) return null;
    return MeasurementRecord.fromFirestore(doc);
  }

  @override
  Future<void> saveRecord(MeasurementRecord record) async {
    await _collection(record.userId).doc(record.id).set(record.toFirestore());
  }

  @override
  Future<void> updateRecord(MeasurementRecord record) async {
    await _collection(
      record.userId,
    ).doc(record.id).update(record.toFirestore());
  }

  @override
  Future<void> deleteRecord(String id) async {
    final doc = await _findRecordDocById(id);
    if (doc != null && doc.exists) {
      await doc.reference.delete();
    }
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _findRecordDocById(
    String id,
  ) async {
    final snapshot = await _firestore
        .collectionGroup('records')
        .where(FieldPath.documentId, isEqualTo: id)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      return null;
    }
    return snapshot.docs.first;
  }
}
