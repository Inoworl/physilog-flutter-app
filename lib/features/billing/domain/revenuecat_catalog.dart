abstract final class RevenueCatCatalog {
  static const personalFamilyEntitlementId = 'personal_family';
  static const teamEntitlementId = 'team';

  /// dev / prodとStoreをまたいで共通に使うRevenueCat Package ID。
  static const personalFamilyMonthlyPackageId = 'personal_family_monthly';
  static const personalFamilyYearlyPackageId = 'personal_family_yearly';
  static const teamMonthlyPackageId = 'team_monthly';
  static const teamYearlyPackageId = 'team_yearly';

  // Test Store product IDs intentionally match the cross-platform package IDs.
  static const personalFamilyMonthlyProductId = personalFamilyMonthlyPackageId;
  static const personalFamilyYearlyProductId = personalFamilyYearlyPackageId;
  static const teamMonthlyProductId = teamMonthlyPackageId;
  static const teamYearlyProductId = teamYearlyPackageId;

  static const defaultOfferingId = 'default';
}
