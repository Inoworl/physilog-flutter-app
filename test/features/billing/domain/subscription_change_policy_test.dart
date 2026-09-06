import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/billing/domain/billing_product.dart';
import 'package:physi_log/features/billing/domain/billing_purchase_request.dart';
import 'package:physi_log/features/billing/domain/billing_subscription.dart';
import 'package:physi_log/features/billing/domain/plan_access_policy.dart';
import 'package:physi_log/features/billing/domain/revenuecat_catalog.dart';
import 'package:physi_log/features/billing/domain/subscription_change_policy.dart';

void main() {
  const policy = SubscriptionChangePolicy();

  group('SubscriptionChangePolicy', () {
    test('契約がなければ新規購入にする', () {
      final request = policy.createRequest(
        current: null,
        target: _personalMonthly,
      );

      expect(request, isNotNull);
      expect(request?.changeType, SubscriptionChangeType.newPurchase);
      expect(request?.previousProductId, isNull);
      expect(request?.replacementMode, isNull);
      expect(request?.timing, SubscriptionChangeTiming.immediate);
    });

    test('現在の商品は購入リクエストを作らない', () {
      final request = policy.createRequest(
        current: _subscription(
          productId: RevenueCatCatalog.personalFamilyMonthlyProductId,
          tier: PlanTier.personalFamily,
          period: BillingPeriod.monthly,
        ),
        target: _personalMonthly,
      );

      expect(request, isNull);
    });

    test('個人・家族からTeamは即時アップグレードにする', () {
      final request = policy.createRequest(
        current: _subscription(
          productId: RevenueCatCatalog.personalFamilyMonthlyProductId,
          tier: PlanTier.personalFamily,
          period: BillingPeriod.monthly,
        ),
        target: _teamMonthly,
      );

      expect(request?.changeType, SubscriptionChangeType.upgrade);
      expect(
        request?.replacementMode,
        BillingReplacementMode.withTimeProration,
      );
      expect(request?.timing, SubscriptionChangeTiming.immediate);
      expect(
        request?.previousProductId,
        RevenueCatCatalog.personalFamilyMonthlyProductId,
      );
    });

    test('Teamから個人・家族は次回更新時ダウングレードにする', () {
      final request = policy.createRequest(
        current: _subscription(
          productId: RevenueCatCatalog.teamMonthlyProductId,
          tier: PlanTier.team,
          period: BillingPeriod.monthly,
        ),
        target: _personalMonthly,
      );

      expect(request?.changeType, SubscriptionChangeType.downgrade);
      expect(request?.replacementMode, BillingReplacementMode.deferred);
      expect(request?.timing, SubscriptionChangeTiming.nextRenewal);
    });

    test('同一Tierの月額から年額は次回更新時の周期変更にする', () {
      final request = policy.createRequest(
        current: _subscription(
          productId: RevenueCatCatalog.personalFamilyMonthlyProductId,
          tier: PlanTier.personalFamily,
          period: BillingPeriod.monthly,
        ),
        target: _personalYearly,
      );

      expect(request?.changeType, SubscriptionChangeType.periodChange);
      expect(request?.replacementMode, BillingReplacementMode.deferred);
      expect(request?.timing, SubscriptionChangeTiming.nextRenewal);
    });

    test('Google Playの同一Subscription内の周期変更に有効な置換条件を使う', () {
      final request = policy.createRequest(
        current: _subscription(
          productId: 'personal_family:monthly',
          tier: PlanTier.personalFamily,
          period: BillingPeriod.monthly,
          store: BillingStore.playStore,
        ),
        target: const BillingProduct(
          packageId: 'personal_family_yearly',
          productId: 'personal_family:yearly',
          tier: PlanTier.personalFamily,
          period: BillingPeriod.yearly,
          title: '個人・家族 年額',
          priceText: '¥1,000',
        ),
      );

      expect(request?.previousProductId, 'personal_family');
      expect(request?.replacementMode?.name, 'withoutProration');
      expect(request?.timing, SubscriptionChangeTiming.nextRenewal);
    });
  });
}

BillingSubscription _subscription({
  required String productId,
  required PlanTier tier,
  required BillingPeriod period,
  BillingStore store = BillingStore.testStore,
}) {
  return BillingSubscription(
    entitlementId: tier == PlanTier.team
        ? RevenueCatCatalog.teamEntitlementId
        : RevenueCatCatalog.personalFamilyEntitlementId,
    productId: productId,
    tier: tier,
    period: period,
    store: store,
    isActive: true,
    willRenew: true,
  );
}

const _personalMonthly = BillingProduct(
  packageId: r'$rc_monthly',
  productId: RevenueCatCatalog.personalFamilyMonthlyProductId,
  tier: PlanTier.personalFamily,
  period: BillingPeriod.monthly,
  title: '個人・家族 月額',
  priceText: '¥500',
);

const _personalYearly = BillingProduct(
  packageId: r'$rc_annual',
  productId: RevenueCatCatalog.personalFamilyYearlyProductId,
  tier: PlanTier.personalFamily,
  period: BillingPeriod.yearly,
  title: '個人・家族 年額',
  priceText: '¥5,000',
);

const _teamMonthly = BillingProduct(
  packageId: 'team_monthly',
  productId: RevenueCatCatalog.teamMonthlyProductId,
  tier: PlanTier.team,
  period: BillingPeriod.monthly,
  title: 'Team 月額',
  priceText: '¥1,000',
);
