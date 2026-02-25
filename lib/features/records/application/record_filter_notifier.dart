import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:physi_log/features/records/domain/record_filter.dart';

final recordFilterNotifierProvider =
    StateNotifierProvider<RecordFilterNotifier, RecordFilter>((ref) {
      return RecordFilterNotifier();
    });

class RecordFilterNotifier extends StateNotifier<RecordFilter> {
  RecordFilterNotifier() : super(const RecordFilter());

  void setAthleteName(String? name) {
    state = state.copyWith(athleteName: name);
  }

  void setEventType(String? type) {
    state = state.copyWith(eventType: type);
  }

  void setDateRange(DateTime? from, DateTime? to) {
    state = state.copyWith(dateFrom: from, dateTo: to);
  }

  void setSortKey(RecordSortKey sortKey) {
    state = state.copyWith(sortKey: sortKey);
  }

  void clearFilter() {
    state = const RecordFilter();
  }
}
