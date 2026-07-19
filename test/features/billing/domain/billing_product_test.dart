import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/features/billing/domain/billing_product.dart';
import 'package:physi_log/features/billing/domain/plan_access_policy.dart';

void main() {
  group('BillingProduct', () {
    test('RevenueCat型に依存しない商品情報を保持する', () {
      const product = BillingProduct(
        packageId: r'$rc_monthly',
        productId: 'personal_family_monthly',
        tier: PlanTier.personalFamily,
        period: BillingPeriod.monthly,
        title: '個人・家族 月額',
        priceText: '¥500',
      );

      expect(product.packageId, r'$rc_monthly');
      expect(product.productId, 'personal_family_monthly');
      expect(product.tier, PlanTier.personalFamily);
      expect(product.period, BillingPeriod.monthly);
      expect(product.title, '個人・家族 月額');
      expect(product.priceText, '¥500');
      expect(
        product,
        const BillingProduct(
          packageId: r'$rc_monthly',
          productId: 'personal_family_monthly',
          tier: PlanTier.personalFamily,
          period: BillingPeriod.monthly,
          title: '個人・家族 月額',
          priceText: '¥500',
        ),
      );
    });
  });
}
