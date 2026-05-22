import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
      'measuredAt': (data['recordedAt'] as Timestamp)
          .toDate()
          .toIso8601String(),
      'createdAt': (data['createdAt'] as Timestamp).toDate().toIso8601String(),
      'updatedAt': (data['updatedAt'] as Timestamp).toDate().toIso8601String(),
    });
  }

  Map<String, dynamic> toFirestore() {
    final value = effectiveRecordValue;
    final unit = effectiveRecordUnit;
    return {
      'athleteId': athleteId ?? '',
      'eventId': eventId ?? eventType,
      'recordedAt': Timestamp.fromDate(measuredAt),
      'value': value,
      'unit': unit,
      'athleteNameSnapshot': athleteName,
      'eventNameSnapshot': eventType,
      'eventUnitSnapshot': unit,
      if (memo.isNotEmpty) 'note': memo,
      'startMs': startMs,
      'endMs': endMs,
      'durationMs': durationMs,
      if (videoRef != null) 'videoRef': videoRef,
      if (fps != null) 'fps': fps,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  bool get hasVideoReference => videoRef != null && videoRef!.trim().isNotEmpty;

  bool get hasRecordValue =>
      recordValue != null &&
      recordUnit != null &&
      recordUnit!.trim().isNotEmpty;

  double get effectiveRecordValue {
    if (hasRecordValue) {
      return recordValue!;
    }
    return durationMs / 1000;
  }

  String get effectiveRecordUnit {
    if (hasRecordValue) {
      return recordUnit!.trim();
    }
    return '秒';
  }

  String get formattedRecordValue {
    final value = effectiveRecordValue;
    final display = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return '$display$effectiveRecordUnit';
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
