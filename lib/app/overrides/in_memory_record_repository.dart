import 'package:physi_log/features/records/domain/record_filter.dart';
import 'package:physi_log/features/records/domain/record_repository.dart';
import 'package:physi_log/models/measurement_record.dart';

class InMemoryRecordRepository implements RecordRepository {
  InMemoryRecordRepository([List<MeasurementRecord>? initialRecords])
    : _records = [...?initialRecords];

  final List<MeasurementRecord> _records;

  @override
  Future<void> deleteRecord({
    required String userId,
    required String id,
  }) async {
    _records.removeWhere((record) => record.id == id);
  }

  @override
  Future<MeasurementRecord?> getRecord({
    required String userId,
    required String id,
  }) async {
    for (final record in _records) {
      if (record.id == id && record.userId == userId) {
        return record;
      }
    }
    return null;
  }

  @override
  Future<List<MeasurementRecord>> getRecords({
    required String userId,
    RecordFilter? filter,
    int limit = 20,
    MeasurementRecord? lastRecord,
  }) async {
    return _records.where((record) => record.userId == userId).toList();
  }

  @override
  Future<List<MeasurementRecord>> getAllRecords({
    required String userId,
  }) async {
    final records = _records
        .where((record) => record.userId == userId)
        .toList();
    records.sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
    return records;
  }

  @override
  Future<void> saveRecord(MeasurementRecord record) async {
    _records.add(record);
  }

  @override
  Future<void> updateRecord(MeasurementRecord record) async {
    final index = _records.indexWhere((item) => item.id == record.id);
    if (index != -1) {
      _records[index] = record;
    }
  }
}
