import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:physi_log/features/measurement/application/best_record_policy.dart';
import 'package:physi_log/features/records/domain/record_filter.dart';
import 'package:physi_log/features/records/domain/record_repository.dart';
import 'package:physi_log/models/event.dart';
import 'package:physi_log/models/measurement_record.dart';
import 'package:physi_log/providers/app_providers.dart';
import 'package:uuid/uuid.dart';

/// 計測会の1選手ぶんの状態（その種目・その日のベスト記録と試技数）。
class SessionEntry {
  const SessionEntry({required this.record, required this.attemptCount});

  /// 1選手×1種目×1日＝1レコードに上書きする運用なので、保持するのは1件だけ。
  final MeasurementRecord record;

  /// その日その種目で何本測ったか（不採用ぶんも含む）。
  final int attemptCount;

  String get athleteId => record.athleteId ?? '';
  String get athleteName => record.athleteName;
  double get bestValue => record.effectiveRecordValue;
  String get unit => record.effectiveRecordUnit;
  String get formattedBest => record.formattedRecordValue;

  SessionEntry copyWith({MeasurementRecord? record, int? attemptCount}) {
    return SessionEntry(
      record: record ?? this.record,
      attemptCount: attemptCount ?? this.attemptCount,
    );
  }
}

/// 計測会モードの状態。種目と日付は最初に固定し、選手ごとのベストを貯めていく。
class MeasurementSessionState {
  const MeasurementSessionState({
    required this.event,
    required this.date,
    this.entries = const <String, SessionEntry>{},
    this.isRestoring = true,
  });

  final Event event;

  /// 計測会の日付（今日固定。表示用に日付のみ保持）。
  final DateTime date;

  /// 選手ID → その選手のベスト記録。
  final Map<String, SessionEntry> entries;

  /// 当日同種目の既存記録から復元中かどうか。
  final bool isRestoring;

  /// 計測済みの選手数。
  int get measuredCount => entries.length;

  SessionEntry? entryFor(String athleteId) => entries[athleteId];

  bool hasMeasured(String athleteId) => entries.containsKey(athleteId);

  MeasurementSessionState copyWith({
    Map<String, SessionEntry>? entries,
    bool? isRestoring,
  }) {
    return MeasurementSessionState(
      event: event,
      date: date,
      entries: entries ?? this.entries,
      isRestoring: isRestoring ?? this.isRestoring,
    );
  }
}

/// 計測会プロバイダの引数（種目＋日付）。日付を変えると別の計測会になる。
class SessionArgs {
  const SessionArgs({required this.event, required this.date});

  final Event event;
  final DateTime date;

  @override
  bool operator ==(Object other) =>
      other is SessionArgs &&
      other.event == event &&
      other.date.year == date.year &&
      other.date.month == date.month &&
      other.date.day == date.day;

  @override
  int get hashCode => Object.hash(event, date.year, date.month, date.day);
}

final measurementSessionProvider = StateNotifierProvider.autoDispose
    .family<MeasurementSessionNotifier, MeasurementSessionState, SessionArgs>((
      ref,
      args,
    ) {
      return MeasurementSessionNotifier(
        repository: ref.watch(recordRepositoryProvider),
        userId: ref.watch(currentUserIdProvider),
        event: args.event,
        now: args.date,
      );
    });

/// 計測会モードの中核コントローラ。
///
/// - 計測会自体は永続化しない。「当日＋同種目」の記録から状態を組み立てる（再開対応）。
/// - 1試技ごとに [BestRecordPolicy] でベスト採用を自動判定し、1選手×1種目×1日＝
///   1レコードへ上書きする。採用しなかった試技はメモへ退避する。
class MeasurementSessionNotifier
    extends StateNotifier<MeasurementSessionState> {
  MeasurementSessionNotifier({
    required RecordRepository repository,
    required String? userId,
    required Event event,
    DateTime? now,
  }) : _repository = repository,
       _userId = userId,
       _uuid = const Uuid(),
       super(
         MeasurementSessionState(
           event: event,
           date: _dateOnly(now ?? DateTime.now()),
         ),
       ) {
    restore();
  }

  final RecordRepository _repository;
  final String? _userId;
  final Uuid _uuid;

  Event get _event => state.event;
  EventRecordType get _recordType => _event.recordType;

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  /// 当日・同種目の既存記録から計測済み状態を復元する。
  ///
  /// アプリを閉じても、同じ日に同じ種目で開き直せば計測済みが戻る。
  Future<void> restore() async {
    final userId = _userId;
    if (userId == null) {
      state = state.copyWith(isRestoring: false);
      return;
    }

    try {
      // 種目名でフィルタすると、種目名を変更した後に旧名で保存された記録
      // （eventIdは一致）を取りこぼす。日付だけで取得し、種目の一致は
      // _belongsToEvent（eventId優先）で判定する。
      final records = await _repository.getRecords(
        userId: userId,
        filter: RecordFilter(
          dateFrom: state.date,
          dateTo: state.date,
          sortKey: RecordSortKey.measuredAtAsc,
        ),
        // 1日の記録ぶんを取りこぼさないよう十分大きく取る。
        limit: 1000,
      );

      final entries = <String, SessionEntry>{};
      for (final record in records) {
        if (!_belongsToEvent(record)) continue;
        final athleteId = record.athleteId;
        if (athleteId == null || athleteId.isEmpty) continue;

        final attempts = _attemptCountFromMemo(record.memo);
        final existing = entries[athleteId];
        if (existing == null) {
          entries[athleteId] = SessionEntry(
            record: record,
            attemptCount: attempts,
          );
          continue;
        }
        // 念のため複数件あればベストを残す（通常は1件に上書きされている）。
        final better = BestRecordPolicy.isBetter(
          candidate: record.effectiveRecordValue,
          previousBest: existing.bestValue,
          recordType: _recordType,
        );
        entries[athleteId] = SessionEntry(
          record: better ? record : existing.record,
          attemptCount: existing.attemptCount + attempts,
        );
      }

      if (!mounted) return;
      state = state.copyWith(entries: entries, isRestoring: false);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(isRestoring: false);
    }
  }

  /// 1試技を記録する。ベスト採用を自動判定し、結果（更新/維持/初回）を返す。
  ///
  /// [forceAdopt] が true のとき、更新ならずでも今回の値を採用する（1本目の
  /// フレーム指定ミスなどの救済路）。
  Future<BestAttemptDecision> recordAttempt({
    required String athleteId,
    required String athleteName,
    required double value,
    String? unit,
    String? videoRef,
    double? fps,
    bool forceAdopt = false,
  }) async {
    final resolvedUnit = (unit == null || unit.trim().isEmpty)
        ? _recordType.defaultUnit
        : unit.trim();
    final existing = state.entries[athleteId];
    final decision = BestRecordPolicy.evaluate(
      candidate: value,
      previousBest: existing?.bestValue,
      recordType: _recordType,
    );

    final now = DateTime.now();
    final measuredAt = DateTime(
      state.date.year,
      state.date.month,
      state.date.day,
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
      now.microsecond,
    );

    if (existing == null) {
      final record = _buildRecord(
        id: _uuid.v4(),
        athleteId: athleteId,
        athleteName: athleteName,
        value: value,
        unit: resolvedUnit,
        memo: '',
        videoRef: videoRef,
        fps: fps,
        measuredAt: measuredAt,
        createdAt: now,
        updatedAt: now,
      );
      await _repository.saveRecord(record);
      _putEntry(SessionEntry(record: record, attemptCount: 1));
      return decision;
    }

    final adoptCandidate =
        decision.isImproved || (decision.isNotImproved && forceAdopt);
    final base = existing.record;
    final newValue = adoptCandidate ? value : existing.bestValue;
    final droppedValue = adoptCandidate ? existing.bestValue : value;
    final newMemo = BestRecordPolicy.appendDroppedAttempt(
      memo: base.memo,
      droppedValue: droppedValue,
      unit: resolvedUnit,
    );
    final durationMs = _durationMsFor(newValue, resolvedUnit);

    final updated = base.copyWith(
      athleteName: athleteName,
      recordValue: newValue,
      recordUnit: resolvedUnit,
      startMs: 0,
      endMs: durationMs,
      durationMs: durationMs,
      videoRef: adoptCandidate ? (videoRef ?? base.videoRef) : base.videoRef,
      fps: adoptCandidate ? (fps ?? base.fps) : base.fps,
      memo: newMemo,
      measuredAt: measuredAt,
      updatedAt: now,
    );
    await _repository.updateRecord(updated);
    _putEntry(
      existing.copyWith(
        record: updated,
        attemptCount: existing.attemptCount + 1,
      ),
    );
    return decision;
  }

  void _putEntry(SessionEntry entry) {
    if (!mounted) return;
    final next = Map<String, SessionEntry>.from(state.entries);
    next[entry.athleteId] = entry;
    state = state.copyWith(entries: next);
  }

  bool _belongsToEvent(MeasurementRecord record) {
    final eventId = record.eventId;
    if (eventId != null && eventId.isNotEmpty) {
      return eventId == _event.id;
    }
    // 旧データ（eventId 無し）は種目名で照合する。
    return record.eventType == _event.name;
  }

  int _durationMsFor(double value, String unit) {
    return unit == '秒' ? (value * 1000).round() : 0;
  }

  MeasurementRecord _buildRecord({
    required String id,
    required String athleteId,
    required String athleteName,
    required double value,
    required String unit,
    required String memo,
    required String? videoRef,
    required double? fps,
    required DateTime measuredAt,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    final durationMs = _durationMsFor(value, unit);
    return MeasurementRecord(
      id: id,
      userId: _userId ?? '',
      athleteId: athleteId,
      eventId: _event.id,
      athleteName: athleteName,
      eventType: _event.name,
      startMs: 0,
      endMs: durationMs,
      durationMs: durationMs,
      recordValue: value,
      recordUnit: unit,
      measuredAt: measuredAt,
      memo: memo,
      videoRef: videoRef,
      fps: fps,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// メモに退避した「不採用」行の数＋1を試技数とみなす。
  static int _attemptCountFromMemo(String memo) {
    if (memo.isEmpty) return 1;
    final dropped = '不採用:'.allMatches(memo).length;
    return dropped + 1;
  }
}
