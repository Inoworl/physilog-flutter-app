import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/billing/domain/billing_product.dart';
import 'package:physi_log/features/billing/domain/billing_subscription.dart';
import 'package:physi_log/features/billing/domain/plan_access_policy.dart';
import 'package:physi_log/features/billing/domain/revenuecat_catalog.dart';

void main() {
  group('BillingSubscription.fromProduct', () {
    test('商品IDからTierと支払い周期を復元する', () {
      final subscription = BillingSubscription.fromProduct(
        entitlementId: RevenueCatCatalog.teamEntitlementId,
        productId: 'team',
        productPlanIdentifier: 'yearly',
        store: BillingStore.playStore,
        isActive: true,
        willRenew: true,
        expiresAt: DateTime.utc(2027),
      );

      expect(subscription, isNotNull);
      expect(subscription?.tier, PlanTier.team);
      expect(subscription?.period, BillingPeriod.yearly);
      expect(subscription?.productId, 'team:yearly');
      expect(subscription?.store, BillingStore.playStore);
      expect(subscription?.isCancellationScheduled, isFalse);
    });

    test('App Storeのplatform固有商品IDからTierと支払い周期を復元する', () {
      final subscription = BillingSubscription.fromProduct(
        entitlementId: RevenueCatCatalog.personalFamilyEntitlementId,
        productId: 'com.inoworl.physilog.personal_family.monthly',
        store: BillingStore.appStore,
        isActive: true,
        willRenew: true,
      );

      expect(subscription?.tier, PlanTier.personalFamily);
      expect(subscription?.period, BillingPeriod.monthly);
    });

    test('未対応の商品IDは契約として扱わない', () {
      final subscription = BillingSubscription.fromProduct(
        entitlementId: 'unsupported',
        productId: 'unsupported_product',
        store: BillingStore.other,
        isActive: true,
        willRenew: false,
      );

      expect(subscription, isNull);
    });

    test('解約検知後も有効期限内ならactive契約として保持する', () {
      final unsubscribeDetectedAt = DateTime.utc(2026, 7, 1);
      final subscription = BillingSubscription.fromProduct(
        entitlementId: RevenueCatCatalog.personalFamilyEntitlementId,
        productId: RevenueCatCatalog.personalFamilyMonthlyProductId,
        store: BillingStore.appStore,
        isActive: true,
        willRenew: false,
        expiresAt: DateTime.utc(2026, 8, 1),
        unsubscribeDetectedAt: unsubscribeDetectedAt,
      );

      expect(subscription?.isActive, isTrue);
      expect(subscription?.isCancellationScheduled, isTrue);
      expect(subscription?.unsubscribeDetectedAt, unsubscribeDetectedAt);
    });
  });
}
