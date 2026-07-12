import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/measurement/application/measurement_session_notifier.dart';
import 'package:physi_log/features/measurement/application/session_video_loop_notifier.dart';
import 'package:physi_log/features/records/application/record_list_notifier.dart';
import 'package:physi_log/features/records/domain/record_filter.dart';
import 'package:physi_log/features/records/domain/record_repository.dart';
import 'package:physi_log/models/event.dart';
import 'package:physi_log/models/measurement_record.dart';
import 'package:physi_log/providers/app_providers.dart';

/// テスト用のインメモリ記録リポジトリ（measurement_session_notifier_test.dart と同型）。
class _InMemoryRecordRepository implements RecordRepository {
  final Map<String, MeasurementRecord> _records = {};

  @override
  Future<List<MeasurementRecord>> getRecords({
    required String userId,
    RecordFilter? filter,
    int limit = 20,
    MeasurementRecord? lastRecord,
  }) async {
    return _records.values.where((r) => r.userId == userId).toList()
      ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
  }

  @override
  Future<List<MeasurementRecord>> getAllRecords({
    required String userId,
  }) async {
    return _records.values.where((r) => r.userId == userId).toList()
      ..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
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

/// recordAttempt が呼ぶ ref.invalidate(recordListNotifierProvider) 用の無害な
/// スタブ。本物は非autoDisposeでアプリが生きている間に非同期読み込みが解決するが、
/// このテストのProviderContainerはテスト単位で作って捨てるため、読み込み完了前に
/// disposeされてクラッシュする恐れがある。この notifier のテスト対象ではないため、
/// loadRecords を no-op にして非同期の競合を根本的に無くす。
class _NoopRecordListNotifier extends RecordListNotifier {
  _NoopRecordListNotifier()
    : super(_InMemoryRecordRepository(), 'user-1', const RecordFilter());

  @override
  Future<void> loadRecords() async {}
}

Event _event() {
  final now = DateTime(2026, 7, 1);
  return Event(
    id: 'event-1',
    userId: 'user-1',
    name: '30m走',
    measurementMethod: EventMeasurementMethod.video,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late _InMemoryRecordRepository repo;
  late ProviderContainer container;
  late SessionArgs args;

  setUp(() async {
    repo = _InMemoryRecordRepository();
    container = ProviderContainer(
      overrides: [
        recordRepositoryProvider.overrideWithValue(repo),
        // authStateProvider（Firebase依存）を経由させないよう、userIdは直接固定する。
        currentUserIdProvider.overrideWithValue('user-1'),
        // recordAttempt が invalidate するが、このテストの対象ではないため
        // 非同期読み込みをno-opにして disposeタイミングとの競合を無くす。
        recordListNotifierProvider.overrideWith(
          (ref) => _NoopRecordListNotifier(),
        ),
      ],
    );
    args = SessionArgs(event: _event(), date: DateTime(2026, 7, 1));
    // measurementSessionProvider のコンストラクタの restore 完了を待つ。
    await container.read(measurementSessionProvider(args).notifier).restore();
  });

  tearDown(() => container.dispose());

  test('recordAttempt は保存中の二重実行をブロックする（後勝ちは無視されnullを返す）', () async {
    final notifier = container.read(sessionVideoLoopProvider(args).notifier);

    // 1本目を発行した直後（awaitする前）に2本目を発行し、二重実行を試みる。
    final first = notifier.recordAttempt(
      athleteId: 'a1',
      athleteName: 'たろう',
      value: 7.2,
      fps: 60,
    );
    final second = notifier.recordAttempt(
      athleteId: 'a1',
      athleteName: 'たろう',
      value: 7.5,
      fps: 60,
    );

    final firstResult = await first;
    final secondResult = await second;

    expect(firstResult, isNotNull);
    expect(secondResult, isNull); // ガードにより即nullで弾かれる

    final saved = await repo.getRecords(userId: 'user-1');
    expect(saved.length, 1); // 二重保存されていない
    expect(saved.single.effectiveRecordValue, 7.2);
  });

  test('recordAttempt 完了後は isSaving が false に戻り、次の保存ができる', () async {
    final notifier = container.read(sessionVideoLoopProvider(args).notifier);

    await notifier.recordAttempt(
      athleteId: 'a1',
      athleteName: 'たろう',
      value: 7.2,
      fps: 60,
    );
    expect(container.read(sessionVideoLoopProvider(args)).isSaving, isFalse);

    final decision = await notifier.recordAttempt(
      athleteId: 'a2',
      athleteName: 'じろう',
      value: 6.8,
      fps: 60,
    );
    expect(decision, isNotNull);

    final saved = await repo.getRecords(userId: 'user-1');
    expect(saved.length, 2);
  });

  test('resetForNextVideo は動画未初期化でも安全に完了し、pickVideo段階に戻る', () async {
    final notifier = container.read(sessionVideoLoopProvider(args).notifier);

    await notifier.recordAttempt(
      athleteId: 'a1',
      athleteName: 'たろう',
      value: 7.2,
      fps: 60,
    );
    await notifier.resetForNextVideo();

    final state = container.read(sessionVideoLoopProvider(args));
    expect(state.step, SessionVideoLoopStep.pickVideo);
    expect(state.videoPath, isNull);
    expect(state.isSaving, isFalse);
  });

  test('prepareSwitchToManual は動画未初期化でも例外を投げない', () async {
    final notifier = container.read(sessionVideoLoopProvider(args).notifier);
    await notifier.prepareSwitchToManual();
    // 例外なく完了すればOK（動画プレイヤーのrelease/計測状態リセットが安全に動く）。
  });
}
