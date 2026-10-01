import '../../billing/domain/plan_access_state.dart';
import '../../billing/domain/recording_scope.dart';
import '../../../models/measurement_record.dart';
import '../domain/record_csv.dart';
import '../domain/record_filter.dart';
import '../domain/record_repository.dart';

class CsvExportQuery {
  const CsvExportQuery({
    this.athleteId,
    this.eventId,
    this.dateFrom,
    this.dateTo,
  });
  final String? athleteId;
  final String? eventId;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  DateTime? get start => dateFrom == null
      ? null
      : DateTime(dateFrom!.year, dateFrom!.month, dateFrom!.day);
  DateTime? get endExclusive => dateTo == null
      ? null
      : DateTime(dateTo!.year, dateTo!.month, dateTo!.day + 1);

  bool includes(MeasurementRecord record) =>
      (athleteId == null || athleteId == record.athleteId) &&
      (eventId == null || eventId == record.eventId) &&
      (start == null || !record.measuredAt.isBefore(start!)) &&
      (endExclusive == null || record.measuredAt.isBefore(endExclusive!));
}

class CsvExportPreview {
  const CsvExportPreview({required this.userId, required this.document});
  final String userId;
  final RecordCsv document;
}

class RecordCsvExportService {
  const RecordCsvExportService({
    required this.repository,
    required this.currentUserId,
    required this.currentPlan,
  });
  final RecordRepository repository;
  final String? Function() currentUserId;
  final PlanAccessState Function() currentPlan;

  void _authorize(String? userId) {
    if (userId == null || userId != currentUserId()) {
      throw const PlanAccessException('アカウントが変わりました。出力画面を開き直してください。');
    }
    final plan = currentPlan();
    if (plan is! PlanAccessReady) {
      throw const PlanAccessException('プランを確認できません。通信状態を確認して再度お試しください。');
    }
    if (!plan.capabilities.canExportCsv) {
      throw const PlanAccessException('CSV出力はTeamプランで利用できます。');
    }
  }

  Future<CsvExportPreview> prepare(CsvExportQuery query) async {
    final userId = currentUserId();
    _authorize(userId);
    if (query.start != null &&
        query.endExclusive != null &&
        !query.start!.isBefore(query.endExclusive!)) {
      throw const PlanAccessException('終了日は開始日以降を選んでください。');
    }
    final records = <MeasurementRecord>[];
    final visited = <String>{};
    final endExclusive = query.endExclusive?.toUtc();
    final filter = RecordFilter(
      athleteId: query.athleteId,
      dateFrom: query.start?.toUtc(),
      dateTo: endExclusive?.subtract(const Duration(days: 1)),
    );
    MeasurementRecord? cursor;
    const pageSize = 250;
    while (true) {
      final page = await repository.getRecords(
        userId: userId!,
        limit: pageSize,
        lastRecord: cursor,
        filter: filter,
      );
      _authorize(userId);
      if (page.isEmpty) break;
      for (final record in page) {
        if (!visited.add(record.id)) {
          throw const PlanAccessException('記録の取得結果が重複しました。時間をおいて再度お試しください。');
        }
        if (visited.length > 10000) {
          throw const PlanAccessException('1回の出力は10,000件までです。期間や選手を絞ってください。');
        }
        if (record.userId == userId && query.includes(record)) {
          records.add(record);
        }
      }
      cursor = page.last;
      if (page.length < pageSize) break;
    }
    records.sort((left, right) {
      final order = left.measuredAt.compareTo(right.measuredAt);
      return order == 0 ? left.id.compareTo(right.id) : order;
    });
    final document = RecordCsv.encode(records);
    _authorize(userId);
    return CsvExportPreview(userId: userId, document: document);
  }

  Future<void> share(
    CsvExportPreview preview,
    Future<void> Function(RecordCsv document, void Function() authorize)
    deliver,
  ) async {
    _authorize(preview.userId);
    await deliver(preview.document, () => _authorize(preview.userId));
  }
}
