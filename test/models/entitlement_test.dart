import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/models/entitlement.dart';

void main() {
  test('activeな据え置き個人・家族entitlementは個人・家族プランとして扱う', () {
    final entitlement = Entitlement(
      id: 'current',
      userId: 'user-1',
      plan: EntitlementPlans.legacyPersonalFamily,
      source: EntitlementSources.manual,
      status: EntitlementStatuses.active,
      grantedAt: DateTime(2026, 5, 27, 10),
      updatedAt: DateTime(2026, 5, 27, 10),
    );

    expect(entitlement.isActiveAt(DateTime(2026, 5, 27, 11)), isTrue);
    expect(
      entitlement.hasLegacyPersonalFamilyAccessAt(DateTime(2026, 5, 27, 11)),
      isTrue,
    );
    expect(
      entitlement.hasLegacyTeamAccessAt(DateTime(2026, 5, 27, 11)),
      isFalse,
    );
    expect(
      entitlement.hasManualTeamAccessAt(DateTime(2026, 5, 27, 11)),
      isFalse,
    );
  });

  test('activeな据え置きTeam entitlementはTeamプランとして扱う', () {
    final entitlement = Entitlement(
      id: 'current',
      userId: 'user-1',
      plan: EntitlementPlans.legacyTeam,
      source: EntitlementSources.manual,
      status: EntitlementStatuses.active,
      grantedAt: DateTime(2026, 5, 27, 10),
      updatedAt: DateTime(2026, 5, 27, 10),
    );

    expect(
      entitlement.hasLegacyTeamAccessAt(DateTime(2026, 5, 27, 11)),
      isTrue,
    );
    expect(
      entitlement.hasLegacyPersonalFamilyAccessAt(DateTime(2026, 5, 27, 11)),
      isFalse,
    );
  });

  test('activeな手動付与Team entitlementはTeamプランとして扱う', () {
    final entitlement = Entitlement(
      id: 'current',
      userId: 'user-1',
      plan: EntitlementPlans.manualTeam,
      source: EntitlementSources.manual,
      status: EntitlementStatuses.active,
      grantedAt: DateTime(2026, 5, 27, 10),
      updatedAt: DateTime(2026, 5, 27, 10),
    );

    expect(
      entitlement.hasManualTeamAccessAt(DateTime(2026, 5, 27, 11)),
      isTrue,
    );
    expect(
      entitlement.hasLegacyTeamAccessAt(DateTime(2026, 5, 27, 11)),
      isFalse,
    );
  });

  test('期限切れまたはrevokedのentitlementはプラン付与として扱わない', () {
    final base = Entitlement(
      id: 'current',
      userId: 'user-1',
      plan: EntitlementPlans.legacyTeam,
      source: EntitlementSources.manual,
      status: EntitlementStatuses.active,
      expiresAt: DateTime(2026, 5, 27, 10),
      grantedAt: DateTime(2026, 5, 1, 10),
      updatedAt: DateTime(2026, 5, 1, 10),
    );

    expect(base.isActiveAt(DateTime(2026, 5, 27, 11)), isFalse);
    expect(base.hasLegacyTeamAccessAt(DateTime(2026, 5, 27, 11)), isFalse);
    expect(
      base
          .copyWith(
            status: EntitlementStatuses.revoked,
            expiresAt: DateTime(2026, 6, 27, 10),
          )
          .hasLegacyTeamAccessAt(DateTime(2026, 5, 27, 11)),
      isFalse,
    );
  });

  test('entitlementはFirestore schemaに合う形で保存する', () {
    final now = DateTime(2026, 5, 27, 10);
    final entitlement = Entitlement(
      id: 'current',
      userId: 'user-1',
      plan: EntitlementPlans.legacyPersonalFamily,
      source: EntitlementSources.manual,
      status: EntitlementStatuses.active,
      productId: 'personal_family_yearly',
      originalTransactionId: 'original-transaction-1',
      purchaseToken: 'purchase-token-1',
      expiresAt: DateTime(2027, 5, 27, 10),
      grantedAt: now,
      updatedAt: now,
    );

    final data = entitlement.toFirestore();

    expect(data['plan'], EntitlementPlans.legacyPersonalFamily);
    expect(data['source'], EntitlementSources.manual);
    expect(data['status'], EntitlementStatuses.active);
    expect(data['productId'], 'personal_family_yearly');
    expect(data['originalTransactionId'], 'original-transaction-1');
    expect(data['purchaseToken'], 'purchase-token-1');
    expect(data['expiresAt'], isA<Timestamp>());
    expect(data['grantedAt'], isA<Timestamp>());
    expect(data['updatedAt'], isA<Timestamp>());
    expect(data, isNot(contains('id')));
    expect(data, isNot(contains('userId')));
  });
}
