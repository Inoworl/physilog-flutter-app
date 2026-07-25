enum SubscriptionChangeType { newPurchase, upgrade, downgrade, periodChange }

enum SubscriptionChangeTiming { immediate, nextRenewal }

enum BillingReplacementMode { withTimeProration, deferred }

class BillingPurchaseRequest {
  const BillingPurchaseRequest({
    required this.packageId,
    required this.productId,
    required this.changeType,
    required this.timing,
    this.previousProductId,
    this.replacementMode,
  });

  final String packageId;
  final String productId;
  final String? previousProductId;
  final SubscriptionChangeType changeType;
  final SubscriptionChangeTiming timing;
  final BillingReplacementMode? replacementMode;

  bool get isDeferred {
    return replacementMode == BillingReplacementMode.deferred;
  }

  @override
  bool operator ==(Object other) {
    return other is BillingPurchaseRequest &&
        other.packageId == packageId &&
        other.productId == productId &&
        other.previousProductId == previousProductId &&
        other.changeType == changeType &&
        other.timing == timing &&
        other.replacementMode == replacementMode;
  }

  @override
  int get hashCode {
    return Object.hash(
      packageId,
      productId,
      previousProductId,
      changeType,
      timing,
      replacementMode,
    );
  }
}
