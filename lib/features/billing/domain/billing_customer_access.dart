import 'revenuecat_catalog.dart';

class BillingCustomerAccess {
  factory BillingCustomerAccess({required Set<String> activeEntitlementIds}) {
    return BillingCustomerAccess._(Set.unmodifiable(activeEntitlementIds));
  }

  const BillingCustomerAccess._(this.activeEntitlementIds);

  final Set<String> activeEntitlementIds;

  bool get hasPersonalFamily {
    return activeEntitlementIds.contains(
      RevenueCatCatalog.personalFamilyEntitlementId,
    );
  }

  bool get hasTeam {
    return activeEntitlementIds.contains(RevenueCatCatalog.teamEntitlementId);
  }

  @override
  bool operator ==(Object other) {
    return other is BillingCustomerAccess &&
        other.activeEntitlementIds.length == activeEntitlementIds.length &&
        other.activeEntitlementIds.containsAll(activeEntitlementIds);
  }

  @override
  int get hashCode {
    final sortedIds = activeEntitlementIds.toList()..sort();
    return Object.hashAll(sortedIds);
  }
}
