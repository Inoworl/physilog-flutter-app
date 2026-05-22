import 'package:physi_log/models/measurement_record.dart';

import 'record_filter.dart';

abstract class RecordRepository {
  Future<List<MeasurementRecord>> getRecords({
    required String userId,
    RecordFilter? filter,
    int limit = 20,
    MeasurementRecord? lastRecord,
  });

  Future<MeasurementRecord?> getRecord({
    required String userId,
    required String id,
  });

  Future<void> saveRecord(MeasurementRecord record);

  Future<void> updateRecord(MeasurementRecord record);

  Future<void> deleteRecord({required String userId, required String id});
}
