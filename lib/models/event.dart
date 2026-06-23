import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'event.freezed.dart';
part 'event.g.dart';

/// 記録の型。表示単位・キーパッド・ベスト判定の方向を決める。
enum EventRecordType {
  @JsonValue('time')
  time('秒', 'タイム（秒）', lowerIsBetter: true),
  @JsonValue('count')
  count('回', '回数（回）', lowerIsBetter: false),
  @JsonValue('distance')
  distance('cm', '距離（cm）', lowerIsBetter: false);

  const EventRecordType(
    this.defaultUnit,
    this.label, {
    required this.lowerIsBetter,
  });

  /// 既定の表示単位（秒 / 回 / cm）。
  final String defaultUnit;

  /// フォームなどで表示するラベル。
  final String label;

  /// ベスト判定の方向。タイムは小さいほど良い、回数・距離は大きいほど良い。
  final bool lowerIsBetter;

  /// 記録の型に応じた既定の計測方法。タイムは動画計測、それ以外は手入力。
  EventMeasurementMethod get defaultMeasurementMethod => this == time
      ? EventMeasurementMethod.video
      : EventMeasurementMethod.manual;
}

/// 計測方法。計測会モードのループ分岐に使う。
enum EventMeasurementMethod {
  @JsonValue('video')
  video('動画から計測'),
  @JsonValue('manual')
  manual('手入力');

  const EventMeasurementMethod(this.label);

  /// フォームなどで表示するラベル。
  final String label;
}

@freezed
class Event with _$Event {
  const factory Event({
    required String id,
    required String userId,
    required String name,
    @Default('秒') String unit,
    @Default(EventRecordType.time) EventRecordType recordType,
    @Default(EventMeasurementMethod.video)
    EventMeasurementMethod measurementMethod,
    @Default(0) int sortOrder,
    DateTime? deletedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Event;

  const Event._();

  factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);

  factory Event.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Event.fromJson({
      'id': doc.id,
      'userId': doc.reference.parent.parent?.id ?? '',
      ...data,
      'createdAt': (data['createdAt'] as Timestamp).toDate().toIso8601String(),
      'updatedAt': (data['updatedAt'] as Timestamp).toDate().toIso8601String(),
      if (data['deletedAt'] != null)
        'deletedAt': (data['deletedAt'] as Timestamp)
            .toDate()
            .toIso8601String(),
    });
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'unit': unit,
      // enum の name は @JsonValue と一致させてあるため、fromFirestore 側の
      // 生成 fromJson と読み書き対称になる。
      'recordType': recordType.name,
      'measurementMethod': measurementMethod.name,
      'sortOrder': sortOrder,
      'deletedAt': deletedAt == null ? null : Timestamp.fromDate(deletedAt!),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
