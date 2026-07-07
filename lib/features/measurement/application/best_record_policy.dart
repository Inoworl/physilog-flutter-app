import 'package:physi_log/models/record_value_input.dart';

/// 計測会で1つの試技を評価した結果の種別。
enum BestAttemptOutcome {
  /// その日・その種目・その選手で最初の記録。
  firstAttempt,

  /// 既存ベストを更新した。
  improved,

  /// 既存ベストに及ばなかった。
  notImproved,

  /// 順位をつけない種目（ベスト方向 none）。常に最新値で記録する。
  recorded,
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
  bool get isRecorded => outcome == BestAttemptOutcome.recorded;
}

/// 同日・同選手・同種目の2本目以降をどう扱うかを決める純粋ロジック。
///
/// ベスト方向は種目の [Event.scoreLowerIsBetter]（小さい=true／大きい=false／
/// 順位なし=null）から渡す。単位推測には頼らない。コーチに比較させず
/// アプリ側で自動採用判定する。1選手×1種目×1日＝1レコードに上書きする運用の
/// ため、採用しなかった試技はメモ欄へ退避してデータ構造を増やさずに履歴を残す。
class BestRecordPolicy {
  const BestRecordPolicy._();

  /// candidate が現在のベスト previousBest を更新するか。
  /// 同値は更新とみなさない（先に出した記録を優先）。
  static bool isBetter({
    required double candidate,
    required double previousBest,
    required bool lowerIsBetter,
  }) {
    return lowerIsBetter ? candidate < previousBest : candidate > previousBest;
  }

  /// 既存ベスト previousBest（初回は null）に対して candidate を評価する。
  /// [lowerIsBetter] が null（順位をつけない種目）のときは、常に最新値で記録する。
  static BestAttemptDecision evaluate({
    required double candidate,
    double? previousBest,
    required bool? lowerIsBetter,
  }) {
    if (previousBest == null) {
      return BestAttemptDecision(
        outcome: BestAttemptOutcome.firstAttempt,
        bestValue: candidate,
      );
    }
    if (lowerIsBetter == null) {
      // 順位をつけない種目：比較せず最新値を採用する。
      return BestAttemptDecision(
        outcome: BestAttemptOutcome.recorded,
        bestValue: candidate,
        previousBestValue: previousBest,
      );
    }
    final improved = isBetter(
      candidate: candidate,
      previousBest: previousBest,
      lowerIsBetter: lowerIsBetter,
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
