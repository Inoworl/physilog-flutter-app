import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:physi_log/features/records/application/record_filter_notifier.dart';
import 'package:physi_log/features/records/domain/record_filter.dart';
import 'package:physi_log/features/records/domain/record_repository.dart';
import 'package:physi_log/models/measurement_record.dart';
import 'package:physi_log/providers/app_providers.dart';
import 'package:physi_log/shared/constants/app_constants.dart';

part 'record_list_notifier.freezed.dart';

@freezed
class RecordListState with _$RecordListState {
  const factory RecordListState.loading() = _Loading;
  const factory RecordListState.loaded({
    required List<MeasurementRecord> records,
    @Default(false) bool hasMore,
    @Default(false) bool isLoadingMore,
  }) = _Loaded;
  const factory RecordListState.error(String message) = _Error;
}

final recordListNotifierProvider =
    StateNotifierProvider<RecordListNotifier, RecordListState>((ref) {
      final repository = ref.watch(recordRepositoryProvider);
      final userId = ref.watch(currentUserIdProvider);
      final filter = ref.watch(recordFilterNotifierProvider);
      return RecordListNotifier(repository, userId, filter);
    });

class RecordListNotifier extends StateNotifier<RecordListState> {
  RecordListNotifier(this._repository, this._userId, this._filter)
    : super(const RecordListState.loading()) {
    loadRecords();
  }

  final RecordRepository _repository;
  final String? _userId;
  final RecordFilter _filter;

  Future<void> loadRecords() async {
    if (_userId == null) {
      state = const RecordListState.loaded(records: []);
      return;
    }

    state = const RecordListState.loading();
    try {
      final records = await _repository.getRecords(
        userId: _userId,
        filter: _filter,
        limit: AppConstants.pageSize,
      );
      state = RecordListState.loaded(
        records: records,
        hasMore: records.length >= AppConstants.pageSize,
      );
    } catch (e) {
      state = RecordListState.error('記録の読み込みに失敗しました: $e');
    }
  }

  Future<void> loadMore() async {
    final current = state;
    if (current is! _Loaded || current.isLoadingMore || !current.hasMore) {
      return;
    }
    if (_userId == null) return;

    state = current.copyWith(isLoadingMore: true);
    try {
      final lastRecord = current.records.last;
      final moreRecords = await _repository.getRecords(
        userId: _userId,
        filter: _filter,
        limit: AppConstants.pageSize,
        lastRecord: lastRecord,
      );
      state = RecordListState.loaded(
        records: [...current.records, ...moreRecords],
        hasMore: moreRecords.length >= AppConstants.pageSize,
      );
    } catch (e) {
      state = current.copyWith(isLoadingMore: false);
    }
  }

  Future<void> refresh() async {
    await loadRecords();
  }

  Future<void> deleteRecord(String id) async {
    if (_userId == null) return;
    try {
      await _repository.deleteRecord(userId: _userId, id: id);
      final current = state;
      if (current is _Loaded) {
        final updated = current.records.where((r) => r.id != id).toList();
        state = current.copyWith(records: updated);
      }
    } catch (e) {
      state = RecordListState.error('記録の削除に失敗しました: $e');
    }
  }
}
