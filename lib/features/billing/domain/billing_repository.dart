import 'billing_customer_access.dart';
import 'billing_product.dart';
import 'billing_purchase_request.dart';
import 'billing_purchase_result.dart';

abstract interface class BillingRepository {
  Future<void> configure({required String? appUserId});

  Future<void> identify(String appUserId);

  Future<List<BillingProduct>> fetchProducts();

  Future<BillingPurchaseResult> purchase(BillingPurchaseRequest request);

  Future<BillingCustomerAccess> restorePurchases();

  Future<BillingCustomerAccess> getCustomerAccess();

  Stream<BillingCustomerAccess> watchCustomerAccess();
}
