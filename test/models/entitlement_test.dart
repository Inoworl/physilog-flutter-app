import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/models/entitlement.dart';

void main() {
  test('activeな個人PRO entitlementはProとして扱う', () {
    final entitlement = Entitlement(
      id: 'current',
      userId: 'user-1',
      plan: EntitlementPlans.pro,
      source: EntitlementSources.store,
      status: EntitlementStatuses.active,
      grantedAt: DateTime(2026, 5, 27, 10),
      updatedAt: DateTime(2026, 5, 27, 10),
    );

    expect(entitlement.isActiveAt(DateTime(2026, 5, 27, 11)), isTrue);
    expect(entitlement.hasProAccessAt(DateTime(2026, 5, 27, 11)), isTrue);
    expect(
      entitlement.hasOrganizationAccessAt(DateTime(2026, 5, 27, 11)),
      isFalse,
    );
  });

  test('団体PRO entitlementはPro機能と団体機能を利用できる', () {
    final entitlement = Entitlement(
      id: 'current',
      userId: 'user-1',
      plan: EntitlementPlans.organizationPro,
      source: EntitlementSources.manual,
      status: EntitlementStatuses.active,
      grantedAt: DateTime(2026, 5, 27, 10),
      updatedAt: DateTime(2026, 5, 27, 10),
    );

    expect(entitlement.hasProAccessAt(DateTime(2026, 5, 27, 11)), isTrue);
    expect(
      entitlement.hasOrganizationAccessAt(DateTime(2026, 5, 27, 11)),
      isTrue,
    );
  });

  test('配信初期ユーザー特典 entitlementは無料でProとして扱う', () {
    final entitlement = Entitlement(
      id: 'current',
      userId: 'user-1',
      plan: EntitlementPlans.earlySupporterPro,
      source: EntitlementSources.promo,
      status: EntitlementStatuses.active,
      grantedAt: DateTime(2026, 5, 27, 10),
      updatedAt: DateTime(2026, 5, 27, 10),
    );

    expect(entitlement.hasProAccessAt(DateTime(2026, 5, 27, 11)), isTrue);
    expect(
      entitlement.hasOrganizationAccessAt(DateTime(2026, 5, 27, 11)),
      isFalse,
    );
  });

  test('期限切れまたはrevokedのentitlementはProとして扱わない', () {
    final base = Entitlement(
      id: 'current',
      userId: 'user-1',
      plan: EntitlementPlans.pro,
      source: EntitlementSources.store,
      status: EntitlementStatuses.active,
      expiresAt: DateTime(2026, 5, 27, 10),
      grantedAt: DateTime(2026, 5, 1, 10),
      updatedAt: DateTime(2026, 5, 1, 10),
    );

    expect(base.isActiveAt(DateTime(2026, 5, 27, 11)), isFalse);
    expect(base.hasProAccessAt(DateTime(2026, 5, 27, 11)), isFalse);
    expect(
      base
          .copyWith(
            status: EntitlementStatuses.revoked,
            expiresAt: DateTime(2026, 6, 27, 10),
          )
          .hasProAccessAt(DateTime(2026, 5, 27, 11)),
      isFalse,
    );
  });

  test('entitlementはFirestore schemaに合う形で保存する', () {
    final now = DateTime(2026, 5, 27, 10);
    final entitlement = Entitlement(
      id: 'current',
      userId: 'user-1',
      plan: EntitlementPlans.pro,
      source: EntitlementSources.store,
      status: EntitlementStatuses.active,
      productId: 'physilog_annual',
      originalTransactionId: 'original-transaction-1',
      purchaseToken: 'purchase-token-1',
      expiresAt: DateTime(2027, 5, 27, 10),
      grantedAt: now,
      updatedAt: now,
    );

    final data = entitlement.toFirestore();

    expect(data['plan'], EntitlementPlans.pro);
    expect(data['source'], EntitlementSources.store);
    expect(data['status'], EntitlementStatuses.active);
    expect(data['productId'], 'physilog_annual');
    expect(data['originalTransactionId'], 'original-transaction-1');
    expect(data['purchaseToken'], 'purchase-token-1');
    expect(data['expiresAt'], isA<Timestamp>());
    expect(data['grantedAt'], isA<Timestamp>());
    expect(data['updatedAt'], isA<Timestamp>());
    expect(data, isNot(contains('id')));
    expect(data, isNot(contains('userId')));
  });
}
