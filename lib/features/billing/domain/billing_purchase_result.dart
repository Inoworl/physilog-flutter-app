import 'billing_customer_access.dart';

enum BillingPurchaseStatus { purchased, cancelled, failed }

class BillingPurchaseResult {
  const BillingPurchaseResult.purchased(BillingCustomerAccess customerAccess)
    : this._(
        status: BillingPurchaseStatus.purchased,
        customerAccess: customerAccess,
      );

  const BillingPurchaseResult.cancelled()
    : this._(status: BillingPurchaseStatus.cancelled);

  const BillingPurchaseResult.failed()
    : this._(status: BillingPurchaseStatus.failed);

  const BillingPurchaseResult._({required this.status, this.customerAccess});

  final BillingPurchaseStatus status;
  final BillingCustomerAccess? customerAccess;
}
