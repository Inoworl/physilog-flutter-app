import 'package:hive/hive.dart';
import 'package:physi_log/features/records/domain/record_filter.dart';
import 'package:physi_log/features/records/domain/record_repository.dart';
import 'package:physi_log/models/measurement_record.dart';

class LocalRecordRepository implements RecordRepository {
  static const _boxName = 'records';
  Box<Map>? _box;

  Future<Box<Map>> get box async {
    _box ??= await Hive.openBox<Map>(_boxName);
    return _box!;
  }

  @override
  Future<List<MeasurementRecord>> getRecords({
    required String userId,
    RecordFilter? filter,
    int limit = 20,
    MeasurementRecord? lastRecord,
  }) async {
    final b = await box;
    var records = b.values
        .map((m) => MeasurementRecord.fromJson(Map<String, dynamic>.from(m)))
        .where((r) => r.userId == userId)
        .toList();

    if (filter != null) {
      records = _applyFilter(records, filter);
    }

    _sortRecords(records, filter?.sortKey ?? RecordSortKey.measuredAtDesc);

    if (lastRecord != null) {
      final index = records.indexWhere((r) => r.id == lastRecord.id);
      if (index >= 0) {
        records = records.sublist(index + 1);
      }
    }

    return records.take(limit).toList();
  }

  @override
  Future<MeasurementRecord?> getRecord(String id) async {
    final b = await box;
    final data = b.get(id);
    if (data == null) return null;
    return MeasurementRecord.fromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<void> saveRecord(MeasurementRecord record) async {
    final b = await box;
    await b.put(record.id, record.toJson());
  }

  @override
  Future<void> updateRecord(MeasurementRecord record) async {
    final b = await box;
    await b.put(record.id, record.toJson());
  }

  @override
  Future<void> deleteRecord(String id) async {
    final b = await box;
    await b.delete(id);
  }

  List<MeasurementRecord> _applyFilter(
    List<MeasurementRecord> records,
    RecordFilter filter,
  ) {
    return records.where((r) {
      if (filter.athleteName != null && filter.athleteName!.isNotEmpty) {
        if (!r.athleteName.contains(filter.athleteName!)) return false;
      }
      if (filter.eventType != null && filter.eventType!.isNotEmpty) {
        if (r.eventType != filter.eventType) return false;
      }
      if (filter.dateFrom != null) {
        if (r.measuredAt.isBefore(filter.dateFrom!)) return false;
      }
      if (filter.dateTo != null) {
        final endOfDay = filter.dateTo!.add(const Duration(days: 1));
        if (r.measuredAt.isAfter(endOfDay)) return false;
      }
      return true;
    }).toList();
  }

  void _sortRecords(List<MeasurementRecord> records, RecordSortKey sortKey) {
    switch (sortKey) {
      case RecordSortKey.measuredAtDesc:
        records.sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
      case RecordSortKey.measuredAtAsc:
        records.sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
      case RecordSortKey.durationAsc:
        records.sort((a, b) => a.durationMs.compareTo(b.durationMs));
      case RecordSortKey.durationDesc:
        records.sort((a, b) => b.durationMs.compareTo(a.durationMs));
      case RecordSortKey.athleteName:
        records.sort((a, b) => a.athleteName.compareTo(b.athleteName));
    }
  }
}
