import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/measurement/application/measurement_session_notifier.dart';
import 'package:physi_log/features/records/domain/record_filter.dart';
import 'package:physi_log/features/records/domain/record_repository.dart';
import 'package:physi_log/models/event.dart';
import 'package:physi_log/models/measurement_record.dart';

/// テスト用のインメモリ記録リポジトリ。日別・種目フィルタだけ最低限再現する。
class _InMemoryRecordRepository implements RecordRepository {
  _InMemoryRecordRepository([List<MeasurementRecord>? seed])
    : _records = {for (final r in seed ?? const []) r.id: r};

  final Map<String, MeasurementRecord> _records;

  List<MeasurementRecord> get all => _records.values.toList();

  @override
  Future<List<MeasurementRecord>> getRecords({
    required String userId,
    RecordFilter? filter,
    int limit = 20,
    MeasurementRecord? lastRecord,
  }) async {
    var records = _records.values.where((r) => r.userId == userId).toList();
    if (filter != null) {
      records = records.where((r) {
        if (filter.eventType != null && filter.eventType!.isNotEmpty) {
          if (r.eventType != filter.eventType) return false;
        }
        if (filter.dateFrom != null &&
            r.measuredAt.isBefore(filter.dateFrom!)) {
          return false;
        }
        if (filter.dateTo != null) {
          final endOfDay = filter.dateTo!.add(const Duration(days: 1));
          if (r.measuredAt.isAfter(endOfDay)) return false;
        }
        return true;
      }).toList();
    }
    records.sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    return records.take(limit).toList();
  }

  @override
  Future<MeasurementRecord?> getRecord({
    required String userId,
    required String id,
  }) async => _records[id];

  @override
  Future<void> saveRecord(MeasurementRecord record) async {
    _records[record.id] = record;
  }

  @override
  Future<void> updateRecord(MeasurementRecord record) async {
    _records[record.id] = record;
  }

  @override
  Future<void> deleteRecord({
    required String userId,
    required String id,
  }) async {
    _records.remove(id);
  }
}

Event _event({
  EventRecordType recordType = EventRecordType.time,
  String name = '30m走',
}) {
  return Event(
    id: 'event-1',
    userId: 'user-1',
    name: name,
    unit: recordType.defaultUnit,
    recordType: recordType,
    measurementMethod: recordType.defaultMeasurementMethod,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

MeasurementRecord _seedRecord({
  required String id,
  required String athleteId,
  required String athleteName,
  required double value,
  required String unit,
  required DateTime measuredAt,
  String memo = '',
  String eventId = 'event-1',
  String eventType = '30m走',
}) {
  return MeasurementRecord(
    id: id,
    userId: 'user-1',
    athleteId: athleteId,
    eventId: eventId,
    athleteName: athleteName,
    eventType: eventType,
    startMs: 0,
    endMs: 0,
    durationMs: 0,
    recordValue: value,
    recordUnit: unit,
    measuredAt: measuredAt,
    memo: memo,
    createdAt: measuredAt,
    updatedAt: measuredAt,
  );
}

Future<MeasurementSessionNotifier> _makeNotifier(
  _InMemoryRecordRepository repo, {
  Event? event,
  DateTime? now,
}) async {
  final notifier = MeasurementSessionNotifier(
    repository: repo,
    userId: 'user-1',
    event: event ?? _event(),
    now: now,
  );
  // コンストラクタの restore 完了を待つ。
  await notifier.restore();
  return notifier;
}

void main() {
  group('recordAttempt', () {
    test('初回はそのまま保存され、計測済み1人になる', () async {
      final repo = _InMemoryRecordRepository();
      final notifier = await _makeNotifier(repo);

      final decision = await notifier.recordAttempt(
        athleteId: 'a1',
        athleteName: 'たろう',
        value: 7.35,
      );

      expect(decision.isFirstAttempt, isTrue);
      expect(notifier.state.measuredCount, 1);
      final entry = notifier.state.entryFor('a1')!;
      expect(entry.bestValue, 7.35);
      expect(entry.attemptCount, 1);
      expect(repo.all, hasLength(1));
    });

    test('2本目が速ければ上書き更新し、前のベストはメモへ退避', () async {
      final repo = _InMemoryRecordRepository();
      final notifier = await _makeNotifier(repo);
      await notifier.recordAttempt(
        athleteId: 'a1',
        athleteName: 'たろう',
        value: 7.35,
      );

      final decision = await notifier.recordAttempt(
        athleteId: 'a1',
        athleteName: 'たろう',
        value: 7.21,
      );

      expect(decision.isImproved, isTrue);
      final entry = notifier.state.entryFor('a1')!;
      expect(entry.bestValue, 7.21);
      expect(entry.attemptCount, 2);
      expect(entry.record.memo, contains('不採用: 7.35秒'));
      // レコードは1選手1件のまま（上書き）。
      expect(repo.all, hasLength(1));
    });

    test('2本目が遅ければベスト維持し、今回ぶんをメモへ退避', () async {
      final repo = _InMemoryRecordRepository();
      final notifier = await _makeNotifier(repo);
      await notifier.recordAttempt(
        athleteId: 'a1',
        athleteName: 'たろう',
        value: 7.21,
      );

      final decision = await notifier.recordAttempt(
        athleteId: 'a1',
        athleteName: 'たろう',
        value: 7.4,
      );

      expect(decision.isNotImproved, isTrue);
      final entry = notifier.state.entryFor('a1')!;
      expect(entry.bestValue, 7.21);
      expect(entry.record.memo, contains('不採用: 7.4秒'));
    });

    test('救済路：遅くても forceAdopt なら今回を採用', () async {
      final repo = _InMemoryRecordRepository();
      final notifier = await _makeNotifier(repo);
      await notifier.recordAttempt(
        athleteId: 'a1',
        athleteName: 'たろう',
        value: 7.21,
      );

      final decision = await notifier.recordAttempt(
        athleteId: 'a1',
        athleteName: 'たろう',
        value: 7.4,
        forceAdopt: true,
      );

      expect(decision.isNotImproved, isTrue);
      final entry = notifier.state.entryFor('a1')!;
      expect(entry.bestValue, 7.4);
      expect(entry.record.memo, contains('不採用: 7.21秒'));
    });

    test('距離種目は大きいほうを採用する', () async {
      final repo = _InMemoryRecordRepository();
      final notifier = await _makeNotifier(
        repo,
        event: _event(recordType: EventRecordType.distance, name: '立ち幅跳び'),
      );
      await notifier.recordAttempt(
        athleteId: 'a1',
        athleteName: 'たろう',
        value: 228,
      );

      final decision = await notifier.recordAttempt(
        athleteId: 'a1',
        athleteName: 'たろう',
        value: 235,
      );

      expect(decision.isImproved, isTrue);
      final entry = notifier.state.entryFor('a1')!;
      expect(entry.bestValue, 235);
      expect(entry.unit, 'cm');
    });
  });

  group('restore', () {
    test('当日・同種目の既存記録から計測済みを復元（不採用行から試技数も復元）', () async {
      final today = DateTime(2026, 6, 25, 10);
      final repo = _InMemoryRecordRepository([
        _seedRecord(
          id: 'r1',
          athleteId: 'a1',
          athleteName: 'たろう',
          value: 7.21,
          unit: '秒',
          measuredAt: today,
          memo: '不採用: 7.35秒',
        ),
        _seedRecord(
          id: 'r2',
          athleteId: 'a2',
          athleteName: 'じろう',
          value: 7.5,
          unit: '秒',
          measuredAt: today,
        ),
      ]);

      final notifier = await _makeNotifier(repo, now: today);

      expect(notifier.state.isRestoring, isFalse);
      expect(notifier.state.measuredCount, 2);
      expect(notifier.state.entryFor('a1')!.bestValue, 7.21);
      expect(notifier.state.entryFor('a1')!.attemptCount, 2);
      expect(notifier.state.entryFor('a2')!.attemptCount, 1);
    });

    test('別日の記録は復元対象に含めない', () async {
      final today = DateTime(2026, 6, 25, 10);
      final yesterday = DateTime(2026, 6, 24, 10);
      final repo = _InMemoryRecordRepository([
        _seedRecord(
          id: 'r1',
          athleteId: 'a1',
          athleteName: 'たろう',
          value: 7.21,
          unit: '秒',
          measuredAt: yesterday,
        ),
      ]);

      final notifier = await _makeNotifier(repo, now: today);

      expect(notifier.state.measuredCount, 0);
    });
  });
}
