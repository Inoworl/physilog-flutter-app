import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'athlete.freezed.dart';
part 'athlete.g.dart';

@freezed
class Athlete with _$Athlete {
  const factory Athlete({
    required String id,
    required String userId,
    required String name,
    String? note,
    DateTime? deletedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Athlete;

  const Athlete._();

  factory Athlete.fromJson(Map<String, dynamic> json) =>
      _$AthleteFromJson(json);

  factory Athlete.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Athlete.fromJson({
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
      if (note != null) 'note': note,
      if (deletedAt != null) 'deletedAt': Timestamp.fromDate(deletedAt!),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
