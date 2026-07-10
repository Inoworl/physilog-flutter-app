import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:physi_log/models/record_set.dart';
import 'package:physi_log/models/record_value_input.dart';

part 'measurement_record.freezed.dart';
part 'measurement_record.g.dart';

@freezed
class MeasurementRecord with _$MeasurementRecord {
  const factory MeasurementRecord({
    required String id,
    required String userId,
    String? athleteId,
    String? eventId,
    required String athleteName,
    required String eventType,
    required int startMs,
    required int endMs,
    required int durationMs,
    double? recordValue,
    String? recordUnit,
    required DateTime measuredAt,
    @Default('') String memo,
    String? videoRef,
    double? fps,
    @Default(<RecordSet>[]) List<RecordSet> sets,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _MeasurementRecord;

  const MeasurementRecord._();

  factory MeasurementRecord.fromJson(Map<String, dynamic> json) =>
      _$MeasurementRecordFromJson(json);

  factory MeasurementRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MeasurementRecord.fromJson({
      'id': doc.id,
      'userId': doc.reference.parent.parent?.id ?? '',
      'athleteId': data['athleteId'] as String?,
      'eventId': data['eventId'] as String?,
      'athleteName': data['athleteNameSnapshot'] as String? ?? '',
      'eventType': data['eventNameSnapshot'] as String? ?? '',
      'startMs': data['startMs'] as int? ?? 0,
      'endMs': data['endMs'] as int? ?? 0,
      'durationMs': data['durationMs'] as int? ?? 0,
      'recordValue': (data['value'] as num?)?.toDouble(),
      'recordUnit': data['unit'] as String?,
      'memo': data['note'] as String? ?? '',
      'videoRef': data['videoRef'] as String?,
      'fps': (data['fps'] as num?)?.toDouble(),
      'sets': data['sets'] ?? const <dynamic>[],
      'measuredAt': (data['recordedAt'] as Timestamp)
          .toDate()
          .toIso8601String(),
      'createdAt': (data['createdAt'] as Timestamp).toDate().toIso8601String(),
      'updatedAt': (data['updatedAt'] as Timestamp).toDate().toIso8601String(),
    });
  }

  Map<String, dynamic> toFirestore() {
    final value = effectiveRecordValue;
    final unit = hasRecordValue ? recordUnit?.trim() : effectiveRecordUnit;
    return {
      'athleteId': athleteId ?? '',
      'eventId': eventId ?? eventType,
      'recordedAt': Timestamp.fromDate(measuredAt),
      'value': value,
      'athleteNameSnapshot': athleteName,
      'eventNameSnapshot': eventType,
      if (memo.isNotEmpty) 'note': memo,
      'startMs': startMs,
      'endMs': endMs,
      'durationMs': durationMs,
      if (unit != null && unit.isNotEmpty) 'unit': unit,
      if (videoRef != null) 'videoRef': videoRef,
      if (fps != null) 'fps': fps,
      if (sets.isNotEmpty)
        'sets': sets.map((s) => {'weight': s.weight, 'reps': s.reps}).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  bool get hasVideoReference => videoRef != null && videoRef!.trim().isNotEmpty;

  bool get hasRecordValue => recordValue != null;

  /// ウェイト等でセット（重さ×回数）を持つか。
  bool get hasSets => sets.isNotEmpty;

  /// セット数。
  int get setCount => sets.length;

  /// 「60kg×10 / 70kg×8 / 80kg×5」のようなセット一覧表示。
  String get formattedSets => sets.map((s) => s.formatted).join(' / ');

  double get effectiveRecordValue {
    if (hasRecordValue) {
      return recordValue!;
    }
    return durationMs / 1000;
  }

  String get effectiveRecordUnit {
    if (hasRecordValue) {
      return recordUnit?.trim() ?? '';
    }
    return '秒';
  }

  String get formattedRecordValue {
    return RecordValueInput.formatDisplay(
      recordValue: effectiveRecordValue,
      recordUnit: effectiveRecordUnit,
    );
  }

  String get recordValueInputText {
    if (!hasRecordValue) return '';
    return formattedRecordValue;
  }

  String get formattedDuration {
    return formattedRecordValue;
  }

  String? get accuracyInfo {
    if (fps == null || fps == 0 || !hasVideoReference) return null;
    final accuracy = 1000 / fps!;
    return '±${accuracy.toStringAsFixed(1)}ms (${fps!.toInt()}fps)';
  }
}
