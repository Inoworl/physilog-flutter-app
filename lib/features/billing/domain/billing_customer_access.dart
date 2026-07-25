import 'revenuecat_catalog.dart';
import 'billing_subscription.dart';

class BillingCustomerAccess {
  factory BillingCustomerAccess({
    required Set<String> activeEntitlementIds,
    List<BillingSubscription> activeSubscriptions = const [],
    String? managementUrl,
  }) {
    return BillingCustomerAccess._(
      Set.unmodifiable(activeEntitlementIds),
      List.unmodifiable(activeSubscriptions),
      managementUrl,
    );
  }

  const BillingCustomerAccess._(
    this.activeEntitlementIds,
    this.activeSubscriptions,
    this.managementUrl,
  );

  final Set<String> activeEntitlementIds;
  final List<BillingSubscription> activeSubscriptions;
  final String? managementUrl;

  BillingSubscription? get currentSubscription {
    BillingSubscription? current;
    for (final subscription in activeSubscriptions) {
      if (!subscription.isActive) {
        continue;
      }
      if (current == null ||
          subscription.tier.index > current.tier.index ||
          (subscription.tier == current.tier &&
              _expiresLater(subscription, current))) {
        current = subscription;
      }
    }
    return current;
  }

  Uri? get managementUri {
    final value = managementUrl?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return Uri.tryParse(value);
  }

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
        other.activeEntitlementIds.containsAll(activeEntitlementIds) &&
        _subscriptionsEqual(
          other.activeSubscriptions,
          activeSubscriptions,
        ) &&
        other.managementUrl == managementUrl;
  }

  @override
  int get hashCode {
    final sortedIds = activeEntitlementIds.toList()..sort();
    return Object.hash(
      Object.hashAll(sortedIds),
      Object.hashAll(activeSubscriptions),
      managementUrl,
    );
  }

  static bool _expiresLater(
    BillingSubscription candidate,
    BillingSubscription current,
  ) {
    final candidateExpiration = candidate.expiresAt;
    final currentExpiration = current.expiresAt;
    if (candidateExpiration == null) {
      return currentExpiration != null;
    }
    if (currentExpiration == null) {
      return false;
    }
    return candidateExpiration.isAfter(currentExpiration);
  }

  static bool _subscriptionsEqual(
    List<BillingSubscription> left,
    List<BillingSubscription> right,
  ) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }
}
