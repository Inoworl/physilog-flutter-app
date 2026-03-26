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
    json['measuredAt'] = Timestamp.fromDate(measuredAt);
    json['createdAt'] = Timestamp.fromDate(createdAt);
    json['updatedAt'] = Timestamp.fromDate(updatedAt);
    return json;
  }

  String get formattedDuration {
    final seconds = durationMs / 1000;
    return '${seconds.toStringAsFixed(2)}秒';
  }

  String? get accuracyInfo {
    if (fps == null || fps == 0) return null;
    final accuracy = 1000 / fps!;
    return '±${accuracy.toStringAsFixed(1)}ms (${fps!.toInt()}fps)';
  }
}
