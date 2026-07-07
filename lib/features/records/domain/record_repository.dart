import 'package:physi_log/models/measurement_record.dart';

import 'record_filter.dart';

abstract class RecordRepository {
  Future<List<MeasurementRecord>> getRecords({
    required String userId,
    RecordFilter? filter,
    int limit = 20,
    MeasurementRecord? lastRecord,
  });

  /// 日別シートなど、全記録をまとめて扱う用途向け。measuredAt 降順で返す。
  Future<List<MeasurementRecord>> getAllRecords({required String userId});

  Future<MeasurementRecord?> getRecord({
    required String userId,
    required String id,
  });

  Future<void> saveRecord(MeasurementRecord record);

  Future<void> updateRecord(MeasurementRecord record);

  Future<void> deleteRecord({required String userId, required String id});
}
