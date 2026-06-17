class ProAccessStatus {
  const ProAccessStatus({
    required this.hasRevenueCatPro,
    required this.hasEarlySupporterPro,
    required this.hasOrganizationPro,
  });

  final bool hasRevenueCatPro;
  final bool hasEarlySupporterPro;
  final bool hasOrganizationPro;

  bool get canUsePro =>
      hasRevenueCatPro || hasEarlySupporterPro || hasOrganizationPro;

  bool get canUseOrganizationFeatures => hasOrganizationPro;
}

class ProAccessPolicy {
  const ProAccessPolicy();

  ProAccessStatus evaluate({
    required bool hasRevenueCatPro,
    required bool hasEarlySupporterPro,
    required bool hasOrganizationPro,
  }) {
    return ProAccessStatus(
      hasRevenueCatPro: hasRevenueCatPro,
      hasEarlySupporterPro: hasEarlySupporterPro,
      hasOrganizationPro: hasOrganizationPro,
    );
  }
}
