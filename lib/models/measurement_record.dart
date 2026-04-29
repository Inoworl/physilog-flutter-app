import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'measurement_record.freezed.dart';
part 'measurement_record.g.dart';

@freezed
class MeasurementRecord with _$MeasurementRecord {
  const MeasurementRecord._();

  const factory MeasurementRecord({
    required String id,
    required String userId,
    String? athleteId,
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

  factory MeasurementRecord.fromJson(Map<String, dynamic> json) =>
      _$MeasurementRecordFromJson(json);

  factory MeasurementRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MeasurementRecord.fromJson({
      'id': doc.id,
      ...data,
      'measuredAt': (data['measuredAt'] as Timestamp)
          .toDate()
          .toIso8601String(),
      'createdAt': (data['createdAt'] as Timestamp).toDate().toIso8601String(),
      'updatedAt': (data['updatedAt'] as Timestamp).toDate().toIso8601String(),
    });
  }

  Map<String, dynamic> toFirestore() {
    final json = toJson()..remove('id');
    json.removeWhere((key, value) => value == null);
    json['measuredAt'] = Timestamp.fromDate(measuredAt);
    json['createdAt'] = Timestamp.fromDate(createdAt);
    json['updatedAt'] = Timestamp.fromDate(updatedAt);
    return json;
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
