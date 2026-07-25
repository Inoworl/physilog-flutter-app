import 'billing_product.dart';
import 'plan_access_policy.dart';
import 'revenuecat_catalog.dart';

enum BillingStore { appStore, playStore, testStore, other }

class BillingSubscription {
  const BillingSubscription({
    required this.entitlementId,
    required this.productId,
    required this.tier,
    required this.period,
    required this.store,
    required this.isActive,
    required this.willRenew,
    this.expiresAt,
    this.unsubscribeDetectedAt,
    this.billingIssueDetectedAt,
  });

  static BillingSubscription? fromProduct({
    required String entitlementId,
    required String productId,
    required BillingStore store,
    required bool isActive,
    required bool willRenew,
    DateTime? expiresAt,
    DateTime? unsubscribeDetectedAt,
    DateTime? billingIssueDetectedAt,
  }) {
    final configuration = billingConfigurationForProduct(productId);
    if (configuration == null) {
      return null;
    }

    return BillingSubscription(
      entitlementId: entitlementId,
      productId: productId,
      tier: configuration.tier,
      period: configuration.period,
      store: store,
      isActive: isActive,
      willRenew: willRenew,
      expiresAt: expiresAt,
      unsubscribeDetectedAt: unsubscribeDetectedAt,
      billingIssueDetectedAt: billingIssueDetectedAt,
    );
  }

  final String entitlementId;
  final String productId;
  final PlanTier tier;
  final BillingPeriod period;
  final BillingStore store;
  final bool isActive;
  final bool willRenew;
  final DateTime? expiresAt;
  final DateTime? unsubscribeDetectedAt;
  final DateTime? billingIssueDetectedAt;

  bool get isCancellationScheduled {
    return isActive && (!willRenew || unsubscribeDetectedAt != null);
  }

  bool get hasBillingIssue => billingIssueDetectedAt != null;

  @override
  bool operator ==(Object other) {
    return other is BillingSubscription &&
        other.entitlementId == entitlementId &&
        other.productId == productId &&
        other.tier == tier &&
        other.period == period &&
        other.store == store &&
        other.isActive == isActive &&
        other.willRenew == willRenew &&
        other.expiresAt == expiresAt &&
        other.unsubscribeDetectedAt == unsubscribeDetectedAt &&
        other.billingIssueDetectedAt == billingIssueDetectedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      entitlementId,
      productId,
      tier,
      period,
      store,
      isActive,
      willRenew,
      expiresAt,
      unsubscribeDetectedAt,
      billingIssueDetectedAt,
    );
  }
}

({PlanTier tier, BillingPeriod period})? billingConfigurationForProduct(
  String productId,
) {
  return switch (productId) {
    RevenueCatCatalog.personalFamilyMonthlyProductId => (
      tier: PlanTier.personalFamily,
      period: BillingPeriod.monthly,
    ),
    RevenueCatCatalog.personalFamilyYearlyProductId => (
      tier: PlanTier.personalFamily,
      period: BillingPeriod.yearly,
    ),
    RevenueCatCatalog.teamMonthlyProductId => (
      tier: PlanTier.team,
      period: BillingPeriod.monthly,
    ),
    RevenueCatCatalog.teamYearlyProductId => (
      tier: PlanTier.team,
      period: BillingPeriod.yearly,
    ),
    _ => null,
  };
}
