import 'package:physi_log/features/records/domain/record_filter.dart';
import 'package:physi_log/features/records/domain/record_repository.dart';
import 'package:physi_log/models/measurement_record.dart';

class InMemoryRecordRepository implements RecordRepository {
  InMemoryRecordRepository([List<MeasurementRecord>? initialRecords])
    : _records = [...?initialRecords];

  final List<MeasurementRecord> _records;

  @override
  Future<void> deleteRecord(String id) async {
    _records.removeWhere((record) => record.id == id);
  }

  @override
  Future<MeasurementRecord?> getRecord(String id) async {
    for (final record in _records) {
      if (record.id == id) {
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
