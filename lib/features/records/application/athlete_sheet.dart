import 'package:physi_log/features/records/application/daily_records_notifier.dart';
import 'package:physi_log/models/event.dart';
import 'package:physi_log/models/measurement_record.dart';

/// 選手シートの1行（1計測日）。種目key -> セル。
class AthleteSheetRow {
  const AthleteSheetRow({required this.date, required this.cells});

  final DateTime date;
  final Map<String, DailyCell> cells;
}

/// 選手1人ぶんの記録を「行=計測日・列=種目」で並べた表。
class AthleteSheet {
  const AthleteSheet({required this.columns, required this.rows});

  final List<DailyEventColumn> columns;
  final List<AthleteSheetRow> rows;

  bool get isEmpty => rows.isEmpty;
}

/// 種目が見つからない記録の型を単位から推測する（ベスト方向の取り違え防止）。
EventRecordType _inferType(String unit) {
  switch (unit) {
    case '回':
      return EventRecordType.count;
    case 'cm':
    case 'm':
    case 'mm':
    case 'km':
      return EventRecordType.distance;
    default:
      return EventRecordType.time;
  }
}

/// 1選手ぶんの記録（[records] は当該選手で絞り込み済み）を、
/// 行=計測日（新しい順）・列=種目（sortOrder順）の表に組み立てる純粋関数。
///
/// 同じ日・同じ種目に複数記録があれば、記録の型のベスト方向で1件に集約する。
AthleteSheet buildAthleteSheet({
  required List<MeasurementRecord> records,
  required List<Event> events,
}) {
  final eventById = {for (final e in events) e.id: e};
  final eventByName = {for (final e in events) e.name: e};

  String keyOf(MeasurementRecord r) =>
      (r.eventId != null && r.eventId!.isNotEmpty)
      ? r.eventId!
      : 'name:${r.eventType}';

  final columnMeta = <String, DailyEventColumn>{};
  final sortOrderByKey = <String, int>{};
  final byDay = <DateTime, Map<String, MeasurementRecord>>{};
  final allTimeBest = <String, double>{};

  for (final record in records) {
    final key = keyOf(record);
    // eventId優先、見つからなければ種目名でマスタに紐づける（旧記録対策）。
    // マスタの recordType を使うことで、単位推測に頼らずベスト方向を正しくする。
    final event = (record.eventId != null && record.eventId!.isNotEmpty)
        ? (eventById[record.eventId] ?? eventByName[record.eventType])
        : eventByName[record.eventType];
    final recordType =
        event?.recordType ?? _inferType(record.effectiveRecordUnit);
    // ベスト方向は種目マスタの scoreDirection を使う（単位推測に頼らない）。
    // 旧記録（マスタ無し）のみ単位からの推測で補完する。
    final lowerIsBetter =
        event?.scoreLowerIsBetter ??
        _inferType(record.effectiveRecordUnit).lowerIsBetter;
    final name =
        event?.name ?? (record.eventType.isEmpty ? '未設定' : record.eventType);
    columnMeta[key] = DailyEventColumn(
      key: key,
      name: name,
      recordType: recordType,
      lowerIsBetter: lowerIsBetter,
    );
    sortOrderByKey[key] = event?.sortOrder ?? (1 << 20);

    // 順位なし(null)は最大値を残す扱い（PB/ベストは順位なし種目では意味を持たない）。
    final effectiveLower = lowerIsBetter ?? false;
    final day = DateTime(
      record.measuredAt.year,
      record.measuredAt.month,
      record.measuredAt.day,
    );
    final dayMap = byDay.putIfAbsent(day, () => <String, MeasurementRecord>{});
    final value = record.effectiveRecordValue;
    final existing = dayMap[key];
    if (existing == null) {
      dayMap[key] = record;
    } else {
      final cur = existing.effectiveRecordValue;
      final better = effectiveLower ? value < cur : value > cur;
      if (better) dayMap[key] = record;
    }

    final best = allTimeBest[key];
    if (best == null) {
      allTimeBest[key] = value;
    } else {
      final better = effectiveLower ? value < best : value > best;
      if (better) allTimeBest[key] = value;
    }
  }

  final columns = columnMeta.values.toList()
    ..sort((a, b) {
      final order = sortOrderByKey[a.key]!.compareTo(sortOrderByKey[b.key]!);
      if (order != 0) return order;
      return a.name.compareTo(b.name);
    });

  final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  final rows = <AthleteSheetRow>[];
  for (final day in days) {
    final cells = <String, DailyCell>{};
    byDay[day]!.forEach((key, record) {
      final value = record.effectiveRecordValue;
      final best = allTimeBest[key];
      final isPb = best == null || (value - best).abs() < 1e-9;
      cells[key] = DailyCell(
        recordId: record.id,
        value: value,
        displayText: record.formattedRecordValue,
        isPersonalBest: isPb,
      );
    });
    rows.add(AthleteSheetRow(date: day, cells: cells));
  }

  return AthleteSheet(columns: columns, rows: rows);
}
