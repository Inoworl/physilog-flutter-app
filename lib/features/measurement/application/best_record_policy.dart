import 'package:physi_log/models/event.dart';
import 'package:physi_log/models/record_value_input.dart';

/// 計測会で1つの試技を評価した結果の種別。
enum BestAttemptOutcome {
  /// その日・その種目・その選手で最初の記録。
  firstAttempt,

  /// 既存ベストを更新した。
  improved,

  /// 既存ベストに及ばなかった。
  notImproved,
}

/// 計測会の1試技を評価した結果（純粋データ）。
class BestAttemptDecision {
  const BestAttemptDecision({
    required this.outcome,
    required this.bestValue,
    this.previousBestValue,
  });

  final BestAttemptOutcome outcome;

  /// 採用された（=保存すべき）ベスト値。更新ならず時は既存ベストのまま。
  final double bestValue;

  /// この試技の前のベスト値。初回は null。
  final double? previousBestValue;

  bool get isFirstAttempt => outcome == BestAttemptOutcome.firstAttempt;
  bool get isImproved => outcome == BestAttemptOutcome.improved;
  bool get isNotImproved => outcome == BestAttemptOutcome.notImproved;
}

/// 同日・同選手・同種目の2本目以降をどう扱うかを決める純粋ロジック。
///
/// 記録の型（[EventRecordType.lowerIsBetter]）からベスト方向を導き、
/// コーチに比較させずにアプリ側で自動採用判定する。
/// 1選手×1種目×1日＝1レコードに上書きする運用のため、採用しなかった
/// 試技はメモ欄へ退避してデータ構造を増やさずに履歴を残す。
class BestRecordPolicy {
  const BestRecordPolicy._();

  /// candidate が現在のベスト previousBest を更新するか。
  /// 同値は更新とみなさない（先に出した記録を優先）。
  static bool isBetter({
    required double candidate,
    required double previousBest,
    required EventRecordType recordType,
  }) {
    return recordType.lowerIsBetter
        ? candidate < previousBest
        : candidate > previousBest;
  }

  /// 既存ベスト previousBest（初回は null）に対して candidate を評価する。
  static BestAttemptDecision evaluate({
    required double candidate,
    double? previousBest,
    required EventRecordType recordType,
  }) {
    if (previousBest == null) {
      return BestAttemptDecision(
        outcome: BestAttemptOutcome.firstAttempt,
        bestValue: candidate,
      );
    }
    final improved = isBetter(
      candidate: candidate,
      previousBest: previousBest,
      recordType: recordType,
    );
    return BestAttemptDecision(
      outcome: improved
          ? BestAttemptOutcome.improved
          : BestAttemptOutcome.notImproved,
      bestValue: improved ? candidate : previousBest,
      previousBestValue: previousBest,
    );
  }

  /// 採用しなかった試技をメモへ追記する。既存メモがあれば改行で続ける。
  static String appendDroppedAttempt({
    required String memo,
    required double droppedValue,
    required String unit,
  }) {
    final formatted = RecordValueInput.formatDisplay(
      recordValue: droppedValue,
      recordUnit: unit,
    );
    final note = '不採用: $formatted';
    final base = memo.trimRight();
    if (base.isEmpty) return note;
    return '$base\n$note';
  }
}
