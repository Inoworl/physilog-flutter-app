import '../../records/domain/record_filter.dart';
import '../../records/domain/record_repository.dart';
import '../../../models/measurement_record.dart';
import '../application/recording_access_service.dart';

class PlanLimitedRecordRepository implements RecordRepository {
  const PlanLimitedRecordRepository({
    required RecordRepository repository,
    required RecordingAccessService access,
  }) : _repository = repository,
       _access = access;

  final RecordRepository _repository;
  final RecordingAccessService _access;

  RecordRepository get migrationRepository => _repository;

  @override
  Future<List<MeasurementRecord>> getRecords({
    required String userId,
    RecordFilter? filter,
    int limit = 20,
    MeasurementRecord? lastRecord,
  }) => _repository.getRecords(
    userId: userId,
    filter: filter,
    limit: limit,
    lastRecord: lastRecord,
  );

  @override
  Future<List<MeasurementRecord>> getAllRecords({required String userId}) =>
      _repository.getAllRecords(userId: userId);

  @override
  Future<MeasurementRecord?> getRecord({
    required String userId,
    required String id,
  }) => _repository.getRecord(userId: userId, id: id);

  @override
  Future<void> saveRecord(MeasurementRecord record) async {
    await _access.requireRecord(record);
    await _repository.saveRecord(record);
  }

  @override
  Future<void> updateRecord(MeasurementRecord record) async {
    await _access.requireRecord(record);
    await _repository.updateRecord(record);
  }

  @override
  Future<void> deleteRecord({required String userId, required String id}) =>
      _repository.deleteRecord(userId: userId, id: id);
}
