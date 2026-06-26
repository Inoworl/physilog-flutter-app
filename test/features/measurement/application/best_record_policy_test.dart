import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/measurement/application/best_record_policy.dart';
import 'package:physi_log/models/event.dart';

void main() {
  group('BestRecordPolicy.evaluate', () {
    test('既存ベストが無ければ初回扱い（candidateがそのままベスト）', () {
      final decision = BestRecordPolicy.evaluate(
        candidate: 7.21,
        previousBest: null,
        recordType: EventRecordType.time,
      );

      expect(decision.isFirstAttempt, isTrue);
      expect(decision.bestValue, 7.21);
      expect(decision.previousBestValue, isNull);
    });

    test('タイムは小さいほうが更新（lowerIsBetter）', () {
      final decision = BestRecordPolicy.evaluate(
        candidate: 7.05,
        previousBest: 7.21,
        recordType: EventRecordType.time,
      );

      expect(decision.isImproved, isTrue);
      expect(decision.bestValue, 7.05);
      expect(decision.previousBestValue, 7.21);
    });

    test('タイムで遅い2本目は更新ならず（既存ベスト維持）', () {
      final decision = BestRecordPolicy.evaluate(
        candidate: 7.40,
        previousBest: 7.21,
        recordType: EventRecordType.time,
      );

      expect(decision.isNotImproved, isTrue);
      expect(decision.bestValue, 7.21);
      expect(decision.previousBestValue, 7.21);
    });

    test('距離は大きいほうが更新（higherIsBetter）', () {
      final decision = BestRecordPolicy.evaluate(
        candidate: 235,
        previousBest: 230,
        recordType: EventRecordType.distance,
      );

      expect(decision.isImproved, isTrue);
      expect(decision.bestValue, 235);
    });

    test('回数は小さい2本目だと更新ならず', () {
      final decision = BestRecordPolicy.evaluate(
        candidate: 12,
        previousBest: 15,
        recordType: EventRecordType.count,
      );

      expect(decision.isNotImproved, isTrue);
      expect(decision.bestValue, 15);
    });

    test('同値は更新とみなさない（先の記録を優先）', () {
      final time = BestRecordPolicy.evaluate(
        candidate: 7.21,
        previousBest: 7.21,
        recordType: EventRecordType.time,
      );
      final distance = BestRecordPolicy.evaluate(
        candidate: 230,
        previousBest: 230,
        recordType: EventRecordType.distance,
      );

      expect(time.isNotImproved, isTrue);
      expect(distance.isNotImproved, isTrue);
    });
  });

  group('BestRecordPolicy.appendDroppedAttempt', () {
    test('メモが空なら不採用メモだけになる（秒は整形される）', () {
      final memo = BestRecordPolicy.appendDroppedAttempt(
        memo: '',
        droppedValue: 7.35,
        unit: '秒',
      );

      expect(memo, '不採用: 7.35秒');
    });

    test('既存メモがあれば改行で続ける', () {
      final memo = BestRecordPolicy.appendDroppedAttempt(
        memo: '雨天',
        droppedValue: 228,
        unit: 'cm',
      );

      expect(memo, '雨天\n不採用: 228cm');
    });

    test('複数回の不採用を積み重ねられる', () {
      var memo = BestRecordPolicy.appendDroppedAttempt(
        memo: '',
        droppedValue: 7.35,
        unit: '秒',
      );
      memo = BestRecordPolicy.appendDroppedAttempt(
        memo: memo,
        droppedValue: 7.4,
        unit: '秒',
      );

      expect(memo, '不採用: 7.35秒\n不採用: 7.4秒');
    });
  });
}
