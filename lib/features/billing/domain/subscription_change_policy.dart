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

    final isPlayStoreBasePlanChange =
        current.store == BillingStore.playStore &&
        _playSubscriptionId(current.productId) ==
            _playSubscriptionId(target.productId);
    return _changeRequest(
      current: current,
      target: target,
      changeType: SubscriptionChangeType.periodChange,
      timing: isPlayStoreBasePlanChange
          ? SubscriptionChangeTiming.immediate
          : SubscriptionChangeTiming.nextRenewal,
      previousProductId: isPlayStoreBasePlanChange
          ? _playSubscriptionId(current.productId)
          : null,
      replacementMode: isPlayStoreBasePlanChange
          ? BillingReplacementMode.withoutProration
          : BillingReplacementMode.deferred,
    );
  }

  BillingPurchaseRequest _changeRequest({
    required BillingSubscription current,
    required BillingProduct target,
    required SubscriptionChangeType changeType,
    required SubscriptionChangeTiming timing,
    required BillingReplacementMode replacementMode,
    String? previousProductId,
  }) {
    return BillingPurchaseRequest(
      packageId: target.packageId,
      productId: target.productId,
      previousProductId:
          previousProductId ??
          (current.store == BillingStore.playStore
              ? _playSubscriptionId(current.productId)
              : current.productId),
      changeType: changeType,
      timing: timing,
      replacementMode: replacementMode,
    );
  }

  String _playSubscriptionId(String productId) {
    return productId.split(':').first;
  }
}
