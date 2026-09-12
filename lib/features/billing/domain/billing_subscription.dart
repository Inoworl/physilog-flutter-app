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
    String? productPlanIdentifier,
    required BillingStore store,
    required bool isActive,
    required bool willRenew,
    DateTime? expiresAt,
    DateTime? unsubscribeDetectedAt,
    DateTime? billingIssueDetectedAt,
  }) {
    final normalizedProductId = billingStoreProductIdentifier(
      productId: productId,
      productPlanIdentifier: productPlanIdentifier,
    );
    final configuration = billingConfigurationForProduct(normalizedProductId);
    if (configuration == null) {
      return null;
    }

    return BillingSubscription(
      entitlementId: entitlementId,
      productId: normalizedProductId,
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

/// RevenueCatの環境共通Package IDをアプリ内のプランへ変換する。
({PlanTier tier, BillingPeriod period})? billingConfigurationForPackage(
  String packageId,
) {
  return switch (packageId) {
    RevenueCatCatalog.personalFamilyMonthlyPackageId => (
      tier: PlanTier.personalFamily,
      period: BillingPeriod.monthly,
    ),
    RevenueCatCatalog.personalFamilyYearlyPackageId => (
      tier: PlanTier.personalFamily,
      period: BillingPeriod.yearly,
    ),
    RevenueCatCatalog.teamMonthlyPackageId => (
      tier: PlanTier.team,
      period: BillingPeriod.monthly,
    ),
    RevenueCatCatalog.teamYearlyPackageId => (
      tier: PlanTier.team,
      period: BillingPeriod.yearly,
    ),
    _ => null,
  };
}

/// Test Store、App Store、Google Playの商品IDをアプリ内のプランへ変換する。
({PlanTier tier, BillingPeriod period})? billingConfigurationForProduct(
  String productId,
) {
  if (productId == RevenueCatCatalog.personalFamilyMonthlyProductId ||
      productId == 'personal_family:monthly' ||
      productId.endsWith('.personal_family.monthly')) {
    return (tier: PlanTier.personalFamily, period: BillingPeriod.monthly);
  }
  if (productId == RevenueCatCatalog.personalFamilyYearlyProductId ||
      productId == 'personal_family:yearly' ||
      productId.endsWith('.personal_family.yearly')) {
    return (tier: PlanTier.personalFamily, period: BillingPeriod.yearly);
  }
  if (productId == RevenueCatCatalog.teamMonthlyProductId ||
      productId == 'team:monthly' ||
      productId.endsWith('.team.monthly')) {
    return (tier: PlanTier.team, period: BillingPeriod.monthly);
  }
  if (productId == RevenueCatCatalog.teamYearlyProductId ||
      productId == 'team:yearly' ||
      productId.endsWith('.team.yearly')) {
    return (tier: PlanTier.team, period: BillingPeriod.yearly);
  }
  return null;
}

/// Google Playだけ別々に返されるSubscription IDとBase Plan IDを合成する。
String billingStoreProductIdentifier({
  required String productId,
  String? productPlanIdentifier,
}) {
  final planId = productPlanIdentifier?.trim();
  if (planId == null || planId.isEmpty) {
    return productId;
  }
  return '$productId:$planId';
}
