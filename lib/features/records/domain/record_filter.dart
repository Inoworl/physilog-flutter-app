import 'package:freezed_annotation/freezed_annotation.dart';

part 'record_filter.freezed.dart';

@freezed
class RecordFilter with _$RecordFilter {
  const factory RecordFilter({
    String? athleteId,
    String? athleteName,
    String? eventType,
    DateTime? dateFrom,
    DateTime? dateTo,
    @Default(RecordSortKey.measuredAtDesc) RecordSortKey sortKey,
  }) = _RecordFilter;
}

enum RecordSortKey {
  measuredAtDesc('計測日（新しい順）'),
  measuredAtAsc('計測日（古い順）'),
  durationAsc('タイム（速い順）'),
  durationDesc('タイム（遅い順）'),
  athleteName('選手名');

  const RecordSortKey(this.label);
  final String label;
}
