import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'entitlement.freezed.dart';
part 'entitlement.g.dart';

class EntitlementPlans {
  const EntitlementPlans._();

  static const annual600 = 'annual_600';
  static const annual980 = 'annual_980';
  static const monitorLifetime = 'monitor_lifetime';
}

class EntitlementSources {
  const EntitlementSources._();

  static const store = 'store';
  static const manual = 'manual';
  static const promo = 'promo';
}

class EntitlementStatuses {
  const EntitlementStatuses._();

  static const active = 'active';
  static const expired = 'expired';
  static const revoked = 'revoked';
}

@freezed
class Entitlement with _$Entitlement {
  const factory Entitlement({
    required String id,
    required String userId,
    required String plan,
    required String source,
    required String status,
    String? productId,
    String? originalTransactionId,
    String? purchaseToken,
    DateTime? expiresAt,
    required DateTime grantedAt,
    required DateTime updatedAt,
  }) = _Entitlement;

  const Entitlement._();

  factory Entitlement.fromJson(Map<String, dynamic> json) =>
      _$EntitlementFromJson(json);

  factory Entitlement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Entitlement.fromJson({
      'id': doc.id,
      'userId': doc.reference.parent.parent?.id ?? '',
      ...data,
      if (data['expiresAt'] != null)
        'expiresAt': (data['expiresAt'] as Timestamp)
            .toDate()
            .toIso8601String(),
      'grantedAt': (data['grantedAt'] as Timestamp).toDate().toIso8601String(),
      'updatedAt': (data['updatedAt'] as Timestamp).toDate().toIso8601String(),
    });
  }

  Map<String, dynamic> toFirestore() {
    return {
      'plan': plan,
      'source': source,
      'status': status,
      if (productId != null) 'productId': productId,
      if (originalTransactionId != null)
        'originalTransactionId': originalTransactionId,
      if (purchaseToken != null) 'purchaseToken': purchaseToken,
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
      'grantedAt': Timestamp.fromDate(grantedAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  bool isActiveAt(DateTime at) {
    if (status != EntitlementStatuses.active) {
      return false;
    }
    return expiresAt == null || expiresAt!.isAfter(at);
  }
}
