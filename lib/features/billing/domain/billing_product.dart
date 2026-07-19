import 'plan_access_policy.dart';

enum BillingPeriod { monthly, yearly }

class BillingProduct {
  const BillingProduct({
    required this.packageId,
    required this.productId,
    required this.tier,
    required this.period,
    required this.title,
    required this.priceText,
  });

  final String packageId;
  final String productId;
  final PlanTier tier;
  final BillingPeriod period;
  final String title;
  final String priceText;

  @override
  bool operator ==(Object other) {
    return other is BillingProduct &&
        other.packageId == packageId &&
        other.productId == productId &&
        other.tier == tier &&
        other.period == period &&
        other.title == title &&
        other.priceText == priceText;
  }

  @override
  int get hashCode {
    return Object.hash(packageId, productId, tier, period, title, priceText);
  }
}
