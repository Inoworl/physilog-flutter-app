import 'package:freezed_annotation/freezed_annotation.dart';

part 'measurement_state.freezed.dart';

@freezed
class MeasurementState with _$MeasurementState {
  const factory MeasurementState({
    Duration? startPosition,
    Duration? endPosition,
    Duration? calculatedTime,
    @Default(60.0) double fps,
    @Default('') String athleteName,
    @Default('') String eventType,
    @Default('') String memo,
    @Default(false) bool isSaving,
  }) = _MeasurementState;
}
