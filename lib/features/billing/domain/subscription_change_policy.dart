import 'billing_product.dart';
import 'billing_purchase_request.dart';
import 'billing_subscription.dart';
import 'plan_access_policy.dart';

class SubscriptionChangePolicy {
  const SubscriptionChangePolicy();

  BillingPurchaseRequest? createRequest({
    required BillingSubscription? current,
    required BillingProduct target,
  }) {
    if (current == null) {
      return BillingPurchaseRequest(
        packageId: target.packageId,
        productId: target.productId,
        changeType: SubscriptionChangeType.newPurchase,
        timing: SubscriptionChangeTiming.immediate,
      );
    }

    if (current.productId == target.productId) {
      return null;
    }

    if (current.tier == PlanTier.personalFamily &&
        target.tier == PlanTier.team) {
      return _changeRequest(
        current: current,
        target: target,
        changeType: SubscriptionChangeType.upgrade,
        timing: SubscriptionChangeTiming.immediate,
        replacementMode: BillingReplacementMode.withTimeProration,
      );
    }

    if (current.tier == PlanTier.team &&
        target.tier == PlanTier.personalFamily) {
      return _changeRequest(
        current: current,
        target: target,
        changeType: SubscriptionChangeType.downgrade,
        timing: SubscriptionChangeTiming.nextRenewal,
        replacementMode: BillingReplacementMode.deferred,
      );
    }

    return _changeRequest(
      current: current,
      target: target,
      changeType: SubscriptionChangeType.periodChange,
      timing: SubscriptionChangeTiming.nextRenewal,
      replacementMode: BillingReplacementMode.deferred,
    );
  }

  BillingPurchaseRequest _changeRequest({
    required BillingSubscription current,
    required BillingProduct target,
    required SubscriptionChangeType changeType,
    required SubscriptionChangeTiming timing,
    required BillingReplacementMode replacementMode,
  }) {
    return BillingPurchaseRequest(
      packageId: target.packageId,
      productId: target.productId,
      previousProductId: current.productId,
      changeType: changeType,
      timing: timing,
      replacementMode: replacementMode,
    );
  }
}
