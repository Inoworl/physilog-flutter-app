import 'package:freezed_annotation/freezed_annotation.dart';

part 'record_set.freezed.dart';
part 'record_set.g.dart';

/// ウェイトトレーニングの1セット（重さ×回数）。
///
/// 記録は「1種目に複数セット」を持つため、[MeasurementRecord.sets] に並べる。
@freezed
class RecordSet with _$RecordSet {
  const factory RecordSet({
    /// 重さ（kg）。
    required double weight,

    /// 回数（レップ）。
    required int reps,
  }) = _RecordSet;

  const RecordSet._();

  factory RecordSet.fromJson(Map<String, dynamic> json) =>
      _$RecordSetFromJson(json);

  /// 「60kg×10」のような表示文字列。
  String get formatted => '${_formatWeight(weight)}kg×$reps';

  static String _formatWeight(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }
}
